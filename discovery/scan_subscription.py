#!/usr/bin/env python3
"""Scan an Azure subscription and inventory all resources for the observability accelerator.

Usage:
    python scan_subscription.py --subscription-id <SUB_ID> [--output <PATH>]
"""

import argparse
import json
import re
import sys
from datetime import datetime, timezone

from azure.core.exceptions import ClientAuthenticationError, HttpResponseError
from azure.identity import DefaultAzureCredential
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.subscription import SubscriptionClient

# Regex for validating Azure subscription ID (UUID v4 format)
_UUID_RE = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", re.IGNORECASE
)

# ---------------------------------------------------------------------------
# Azure resource-type -> accelerator category mapping
# ---------------------------------------------------------------------------
RESOURCE_TYPE_MAP: dict[str, str] = {
    "microsoft.compute/virtualmachines": "virtual_machines",
    "microsoft.compute/virtualmachinescalesets": "vmss",
    "microsoft.containerservice/managedclusters": "aks_clusters",
    "microsoft.web/sites": "app_services",  # may be reclassified to function_apps
    "microsoft.sql/servers": "sql_databases",
    "microsoft.sql/servers/databases": "sql_databases",
    "microsoft.storage/storageaccounts": "storage_accounts",
    "microsoft.keyvault/vaults": "key_vaults",
    "microsoft.devices/iothubs": "iot_hubs",
    "microsoft.eventhub/namespaces": "event_hubs",
    "microsoft.documentdb/databaseaccounts": "cosmos_db",
    "microsoft.network/networksecuritygroups": "network_security_groups",
    "microsoft.network/loadbalancers": "load_balancers",
    "microsoft.network/applicationgateways": "application_gateways",
    "microsoft.network/virtualnetworks": "virtual_networks",
    "microsoft.network/privateendpoints": "private_endpoints",
    "microsoft.databricks/workspaces": "databricks",
    "microsoft.logic/workflows": "logic_apps",
}

# Resource types that support publicNetworkAccess property inspection
# Maps resource type -> Azure CLI command prefix for detailed query
NETWORK_INSPECTABLE_TYPES: set[str] = {
    "microsoft.storage/storageaccounts",
    "microsoft.keyvault/vaults",
    "microsoft.sql/servers",
    "microsoft.documentdb/databaseaccounts",
    "microsoft.devices/iothubs",
    "microsoft.eventhub/namespaces",
    "microsoft.containerservice/managedclusters",
    "microsoft.web/sites",
    "microsoft.databricks/workspaces",
}

# All recognised categories (used to seed the output dict so every key exists)
ALL_CATEGORIES = sorted(
    set(RESOURCE_TYPE_MAP.values()) | {"function_apps", "private_endpoints"}
)

# Network-related categories that drive the network-observability feature flag
NETWORK_CATEGORIES = {
    "network_security_groups",
    "load_balancers",
    "application_gateways",
    "virtual_networks",
}

# Mapping from category -> AMBA service short name
AMBA_SERVICE_MAP: dict[str, str] = {
    "virtual_machines": "vm",
    "vmss": "vmss",
    "aks_clusters": "aks",
    "app_services": "app_service",
    "function_apps": "function_app",
    "sql_databases": "sql",
    "storage_accounts": "storage",
    "key_vaults": "key_vault",
    "iot_hubs": "iot_hub",
    "event_hubs": "event_hub",
    "cosmos_db": "cosmos_db",
    "network_security_groups": "nsg",
    "load_balancers": "load_balancer",
    "application_gateways": "app_gateway",
    "virtual_networks": "vnet",
    "databricks": "databricks",
    "logic_apps": "logic_app",
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _resource_group_from_id(resource_id: str) -> str:
    """Extract the resource-group name from a fully-qualified ARM resource id."""
    parts = resource_id.split("/")
    try:
        idx = [p.lower() for p in parts].index("resourcegroups")
        return parts[idx + 1]
    except (ValueError, IndexError):
        return ""


def _is_function_app(resource) -> bool:
    """Return True when a Microsoft.Web/sites resource is actually a Function App."""
    kind = (resource.kind or "").lower()
    return "functionapp" in kind


def _classify_resource(resource) -> str | None:
    """Return the accelerator category for *resource*, or None if unmapped."""
    resource_type = (resource.type or "").lower()

    # Special handling: Web/sites may be a Function App
    if resource_type == "microsoft.web/sites" and _is_function_app(resource):
        return "function_apps"

    return RESOURCE_TYPE_MAP.get(resource_type)


def _serialise_resource(resource) -> dict:
    """Convert a single Azure GenericResourceExpanded to a plain dict."""
    return {
        "id": resource.id,
        "name": resource.name,
        "type": resource.type,
        "location": resource.location,
        "tags": dict(resource.tags) if resource.tags else {},
        "resource_group": _resource_group_from_id(resource.id or ""),
    }


def _check_network_posture(credential, subscription_id: str, resource_list: list) -> dict:
    """Check publicNetworkAccess and private endpoint connections for inspectable resources.

    Uses the generic ARM GET to read each resource's properties, avoiding the need
    for service-specific SDK clients.
    """
    from azure.mgmt.resource import ResourceManagementClient as _RMC

    client = _RMC(credential, subscription_id)
    posture: dict[str, list[dict]] = {
        "public_access_disabled": [],
        "public_access_enabled": [],
        "private_endpoint_connections": [],
        "warnings": [],
    }

    for res in resource_list:
        res_type = (res.type or "").lower()
        if res_type not in NETWORK_INSPECTABLE_TYPES:
            continue

        try:
            # Use generic GET to fetch full resource properties
            full_resource = client.resources.get_by_id(res.id, api_version="2023-01-01")
            props = full_resource.properties or {}
        except HttpResponseError:
            # Some resources need a different API version; try a newer one
            try:
                full_resource = client.resources.get_by_id(res.id, api_version="2024-01-01")
                props = full_resource.properties or {}
            except Exception:
                continue
        except Exception:
            continue

        pna = (props.get("publicNetworkAccess") or "").lower() if isinstance(props, dict) else ""
        pe_connections = props.get("privateEndpointConnections", []) if isinstance(props, dict) else []

        entry = {
            "id": res.id,
            "name": res.name,
            "type": res.type,
            "resource_group": _resource_group_from_id(res.id or ""),
            "public_network_access": pna or "unknown",
        }

        if pna in ("disabled", "denied"):
            posture["public_access_disabled"].append(entry)
            if not pe_connections:
                posture["warnings"].append({
                    "resource": res.name,
                    "type": res.type,
                    "issue": "public_access_disabled_no_private_endpoint",
                    "message": (
                        f"'{res.name}' has publicNetworkAccess=Disabled but no private "
                        f"endpoint connections. Diagnostic logs may not flow to Log Analytics "
                        f"unless Azure trusted services bypass is enabled."
                    ),
                })
        else:
            posture["public_access_enabled"].append(entry)

        if pe_connections:
            for pe in pe_connections:
                pe_props = pe.get("properties", {}) if isinstance(pe, dict) else {}
                posture["private_endpoint_connections"].append({
                    "resource_name": res.name,
                    "resource_type": res.type,
                    "pe_id": pe.get("id", ""),
                    "status": pe_props.get("privateLinkServiceConnectionState", {}).get("status", "unknown"),
                })

    return posture


# ---------------------------------------------------------------------------
# Core scanning logic
# ---------------------------------------------------------------------------

def scan_subscription(subscription_id: str) -> dict:
    """Authenticate, enumerate resources, and return the inventory dict."""

    # --- Validate subscription ID format ---------------------------------
    if not _UUID_RE.match(subscription_id):
        print("ERROR: Invalid subscription ID format.", file=sys.stderr)
        print(f"       Received: '{subscription_id}'", file=sys.stderr)
        print("       Expected: a UUID like 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'", file=sys.stderr)
        sys.exit(1)

    # --- Authenticate ----------------------------------------------------
    try:
        credential = DefaultAzureCredential()
    except ClientAuthenticationError as exc:
        print("ERROR: Azure authentication failed.", file=sys.stderr)
        print("       Could not obtain credentials for Azure.", file=sys.stderr)
        print("", file=sys.stderr)
        print("  How to fix:", file=sys.stderr)
        print("    1. Run 'az login' to authenticate with Azure CLI, OR", file=sys.stderr)
        print("    2. Set environment variables for a service principal:", file=sys.stderr)
        print("         AZURE_TENANT_ID, AZURE_CLIENT_ID, AZURE_CLIENT_SECRET", file=sys.stderr)
        print("    3. If running in Azure, ensure a managed identity is configured.", file=sys.stderr)
        print("", file=sys.stderr)
        print(f"  Azure error: {exc.message}", file=sys.stderr)
        sys.exit(1)

    client = ResourceManagementClient(credential, subscription_id)

    # Seed every category with an empty list
    resources: dict[str, list[dict]] = {cat: [] for cat in ALL_CATEGORIES}
    regions: set[str] = set()

    # --- List resources (with permission checks) -------------------------
    try:
        resource_iterator = client.resources.list()
        # Force the first page to surface auth/permission errors early
        resource_list = list(resource_iterator)
    except ClientAuthenticationError as exc:
        print("ERROR: Azure authentication failed when listing resources.", file=sys.stderr)
        print("       Your credentials may have expired or lack permissions.", file=sys.stderr)
        print("", file=sys.stderr)
        print("  How to fix:", file=sys.stderr)
        print("    1. Run 'az login' to re-authenticate, OR", file=sys.stderr)
        print("    2. Check your service principal credentials are valid.", file=sys.stderr)
        print("", file=sys.stderr)
        print(f"  Azure error: {exc.message}", file=sys.stderr)
        sys.exit(1)
    except HttpResponseError as exc:
        status = exc.status_code
        if status == 403:
            print("ERROR: Access denied (HTTP 403 Forbidden).", file=sys.stderr)
            print(f"       You do not have permission to list resources in subscription '{subscription_id}'.", file=sys.stderr)
            print("", file=sys.stderr)
            print("  Required role: 'Reader' on the subscription.", file=sys.stderr)
            print("", file=sys.stderr)
            print("  How to fix (run as a subscription Owner or User Access Admin):", file=sys.stderr)
            print(f"    az role assignment create \\" , file=sys.stderr)
            print(f"      --assignee <YOUR_USER_OR_SP_OBJECT_ID> \\" , file=sys.stderr)
            print(f"      --role 'Reader' \\" , file=sys.stderr)
            print(f"      --scope '/subscriptions/{subscription_id}'", file=sys.stderr)
        elif status == 404:
            print("ERROR: Subscription not found (HTTP 404).", file=sys.stderr)
            print(f"       The subscription '{subscription_id}' does not exist or is not accessible.", file=sys.stderr)
            print("", file=sys.stderr)
            print("  Check that:", file=sys.stderr)
            print("    - The subscription ID is correct.", file=sys.stderr)
            print("    - Your account has access (run 'az account list' to verify).", file=sys.stderr)
        else:
            print(f"ERROR: Azure API returned HTTP {status}.", file=sys.stderr)
            print(f"       {exc.message}", file=sys.stderr)
        print("", file=sys.stderr)
        print(f"  Azure error: {exc.message}", file=sys.stderr)
        sys.exit(1)

    for res in resource_list:
        category = _classify_resource(res)
        if category is None:
            continue
        resources[category].append(_serialise_resource(res))
        if res.location:
            regions.add(res.location)

    # Remove empty categories from the output
    resources = {k: v for k, v in resources.items() if v}

    total = sum(len(v) for v in resources.values())
    types_found = sorted(resources.keys())
    sorted_regions = sorted(regions)

    # --- network posture scan --------------------------------------------
    print("Checking network posture (publicNetworkAccess, private endpoints)...")
    network_posture = _check_network_posture(credential, subscription_id, resource_list)

    # --- feature flags ---------------------------------------------------
    has_private_restrictions = len(network_posture["public_access_disabled"]) > 0
    has_private_endpoints = len(network_posture["private_endpoint_connections"]) > 0

    feature_flags: dict[str, object] = {
        "enable_aks": "aks_clusters" in resources,
        "enable_iot_hub": "iot_hubs" in resources,
        "enable_network_observability": bool(
            NETWORK_CATEGORIES & set(resources.keys())
        ),
        "enable_amba": total > 0,
        "enable_ampls": has_private_restrictions,
        "amba_services": sorted(
            AMBA_SERVICE_MAP[cat]
            for cat in types_found
            if cat in AMBA_SERVICE_MAP
        ),
    }

    return {
        "subscription_id": subscription_id,
        "scan_timestamp": datetime.now(timezone.utc).isoformat(),
        "summary": {
            "total_resources": total,
            "resource_types_found": types_found,
            "regions": sorted_regions,
        },
        "resources": resources,
        "network_posture": network_posture,
        "feature_flags": feature_flags,
    }


# ---------------------------------------------------------------------------
# Multi-subscription support
# ---------------------------------------------------------------------------

def list_tenant_subscriptions(credential=None) -> list[dict]:
    """List all accessible subscriptions in the current tenant.

    Returns a list of dicts with 'id', 'name', and 'state'.
    """
    if credential is None:
        credential = DefaultAzureCredential()
    client = SubscriptionClient(credential)
    subs = []
    for sub in client.subscriptions.list():
        subs.append({
            "id": sub.subscription_id,
            "name": sub.display_name,
            "state": str(sub.state) if sub.state else "unknown",
        })
    return subs


def scan_multiple_subscriptions(subscription_ids: list[str]) -> dict:
    """Scan multiple subscriptions and return a combined inventory.

    Each subscription gets its own entry in the output. A merged summary
    and combined feature flags are also generated.
    """
    credential = DefaultAzureCredential()
    subscriptions: dict[str, dict] = {}
    merged_resources: dict[str, list[dict]] = {}
    merged_regions: set[str] = set()
    merged_types: set[str] = set()
    all_network_posture = {
        "public_access_disabled": [],
        "public_access_enabled": [],
        "private_endpoint_connections": [],
        "warnings": [],
    }
    all_amba_services: set[str] = set()
    failed_subscriptions: list[dict] = []

    for sub_id in subscription_ids:
        print(f"\n--- Scanning subscription {sub_id} ---")
        try:
            inventory = scan_subscription(sub_id)
            subscriptions[sub_id] = inventory

            # Merge resources (prefix resource IDs already unique via ARM paths)
            for category, res_list in inventory.get("resources", {}).items():
                merged_resources.setdefault(category, []).extend(res_list)

            # Merge summary data
            summary = inventory.get("summary", {})
            merged_regions.update(summary.get("regions", []))
            merged_types.update(summary.get("resource_types_found", []))

            # Merge network posture
            posture = inventory.get("network_posture", {})
            for key in all_network_posture:
                all_network_posture[key].extend(posture.get(key, []))

            # Merge AMBA services
            flags = inventory.get("feature_flags", {})
            all_amba_services.update(flags.get("amba_services", []))

        except SystemExit:
            # scan_subscription calls sys.exit on auth/permission errors
            # Capture and continue to next subscription
            failed_subscriptions.append({
                "subscription_id": sub_id,
                "error": "Authentication or permission error (see output above)",
            })
            print(f"  WARNING: Skipping subscription {sub_id} due to error.")

    # Build merged feature flags
    merged_total = sum(len(v) for v in merged_resources.values())
    merged_feature_flags = {
        "enable_aks": "aks_clusters" in merged_resources,
        "enable_iot_hub": "iot_hubs" in merged_resources,
        "enable_network_observability": bool(
            NETWORK_CATEGORIES & set(merged_resources.keys())
        ),
        "enable_amba": merged_total > 0,
        "enable_ampls": len(all_network_posture["public_access_disabled"]) > 0,
        "amba_services": sorted(all_amba_services),
    }

    return {
        "multi_subscription": True,
        "subscription_ids": subscription_ids,
        "scan_timestamp": datetime.now(timezone.utc).isoformat(),
        "summary": {
            "total_subscriptions": len(subscription_ids),
            "successful_scans": len(subscriptions),
            "failed_scans": len(failed_subscriptions),
            "total_resources": merged_total,
            "resource_types_found": sorted(merged_types),
            "regions": sorted(merged_regions),
        },
        "subscriptions": subscriptions,
        "merged_resources": merged_resources,
        "network_posture": all_network_posture,
        "feature_flags": merged_feature_flags,
        "failed_subscriptions": failed_subscriptions,
    }


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Scan Azure subscription(s) and inventory resources for the observability accelerator.",
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "--subscription-id",
        help="Single Azure subscription ID to scan.",
    )
    group.add_argument(
        "--subscription-ids",
        help="Comma-separated list of subscription IDs to scan.",
    )
    group.add_argument(
        "--tenant-scan",
        action="store_true",
        default=False,
        help="Auto-discover and scan ALL accessible subscriptions in the tenant.",
    )
    parser.add_argument(
        "--output",
        default="discovery/discovered-resources.json",
        help="Path for the JSON output file (default: discovery/discovered-resources.json).",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)

    # Determine which subscriptions to scan
    if args.tenant_scan:
        print("Discovering all subscriptions in tenant...")
        try:
            all_subs = list_tenant_subscriptions()
        except ClientAuthenticationError as exc:
            print("ERROR: Azure authentication failed.", file=sys.stderr)
            print("       Run 'az login' to authenticate.", file=sys.stderr)
            sys.exit(1)
        except HttpResponseError as exc:
            print(f"ERROR: Failed to list subscriptions: {exc.message}", file=sys.stderr)
            sys.exit(1)

        enabled_subs = [s for s in all_subs if s["state"] == "Enabled"]
        print(f"Found {len(all_subs)} subscription(s), {len(enabled_subs)} enabled:")
        for s in enabled_subs:
            print(f"  {s['id']}  {s['name']}")

        if not enabled_subs:
            print("No enabled subscriptions found.")
            sys.exit(0)

        sub_ids = [s["id"] for s in enabled_subs]
    elif args.subscription_ids:
        sub_ids = [s.strip() for s in args.subscription_ids.split(",") if s.strip()]
    else:
        sub_ids = [args.subscription_id]

    # Single subscription: use existing flow
    if len(sub_ids) == 1:
        print(f"Scanning subscription {sub_ids[0]} ...")
        inventory = scan_subscription(sub_ids[0])
    else:
        print(f"\nScanning {len(sub_ids)} subscription(s)...")
        inventory = scan_multiple_subscriptions(sub_ids)

    with open(args.output, "w", encoding="utf-8") as fh:
        json.dump(inventory, fh, indent=2)

    # --- Print summary ---------------------------------------------------
    summary = inventory["summary"]
    is_multi = inventory.get("multi_subscription", False)

    if is_multi:
        print(f"\n{'=' * 70}")
        print(f"  MULTI-SUBSCRIPTION SCAN COMPLETE")
        print(f"{'=' * 70}")
        print(f"  Subscriptions scanned: {summary['successful_scans']}/{summary['total_subscriptions']}")
        if summary["failed_scans"] > 0:
            print(f"  Failed:                {summary['failed_scans']}")
            for f in inventory.get("failed_subscriptions", []):
                print(f"    - {f['subscription_id']}: {f['error']}")

        print(f"  Total resources:       {summary['total_resources']}")
        print(f"  Regions:               {', '.join(summary['regions']) or '(none)'}")
        print(f"  Resource types:        {', '.join(summary['resource_types_found']) or '(none)'}")

        # Per-subscription breakdown
        print(f"\n  Per-subscription breakdown:")
        for sub_id, sub_data in inventory.get("subscriptions", {}).items():
            sub_summary = sub_data.get("summary", {})
            print(f"    {sub_id}: {sub_summary.get('total_resources', 0)} resources, "
                  f"{', '.join(sub_summary.get('resource_types_found', [])) or '(none)'}")

    else:
        print(f"Scan complete. {summary['total_resources']} resource(s) found "
              f"across {len(summary['regions'])} region(s).")
        print(f"Categories: {', '.join(summary['resource_types_found']) or '(none)'}")

    # --- Network posture report ------------------------------------------
    posture = inventory.get("network_posture", {})
    disabled_count = len(posture.get("public_access_disabled", []))
    enabled_count = len(posture.get("public_access_enabled", []))
    pe_count = len(posture.get("private_endpoint_connections", []))
    warnings = posture.get("warnings", [])

    print(f"\nNetwork posture:")
    print(f"  Public access enabled:  {enabled_count} resource(s)")
    print(f"  Public access disabled: {disabled_count} resource(s)")
    print(f"  Private endpoints:      {pe_count} connection(s)")

    if warnings:
        print(f"\n{'!' * 70}")
        print(f"  NETWORK WARNINGS ({len(warnings)})")
        print(f"{'!' * 70}")
        for w in warnings:
            print(f"\n  [{w['type']}] {w['resource']}")
            print(f"    {w['message']}")
        print(f"\n{'!' * 70}")
        if inventory["feature_flags"].get("enable_ampls"):
            print("  Recommendation: Deploy with enable_ampls=true for private link")
            print("  connectivity, or ensure 'Allow trusted Microsoft services' is")
            print("  enabled on each locked-down resource.")
        print(f"{'!' * 70}")

    print(f"\nOutput written to {args.output}")


if __name__ == "__main__":
    main()
