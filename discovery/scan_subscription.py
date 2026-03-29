#!/usr/bin/env python3
"""Scan an Azure subscription and inventory all resources for the observability accelerator.

Usage:
    python scan_subscription.py --subscription-id <SUB_ID> [--output <PATH>]
"""

import argparse
import json
import sys
from datetime import datetime, timezone

from azure.identity import DefaultAzureCredential
from azure.mgmt.resource import ResourceManagementClient

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
    "microsoft.databricks/workspaces": "databricks",
    "microsoft.logic/workflows": "logic_apps",
}

# All recognised categories (used to seed the output dict so every key exists)
ALL_CATEGORIES = sorted(
    set(RESOURCE_TYPE_MAP.values()) | {"function_apps"}
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


# ---------------------------------------------------------------------------
# Core scanning logic
# ---------------------------------------------------------------------------

def scan_subscription(subscription_id: str) -> dict:
    """Authenticate, enumerate resources, and return the inventory dict."""

    credential = DefaultAzureCredential()
    client = ResourceManagementClient(credential, subscription_id)

    # Seed every category with an empty list
    resources: dict[str, list[dict]] = {cat: [] for cat in ALL_CATEGORIES}
    regions: set[str] = set()

    for res in client.resources.list():
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

    # --- feature flags ---------------------------------------------------
    feature_flags: dict[str, object] = {
        "enable_aks": "aks_clusters" in resources,
        "enable_iot_hub": "iot_hubs" in resources,
        "enable_network_observability": bool(
            NETWORK_CATEGORIES & set(resources.keys())
        ),
        "enable_amba": total > 0,
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
        "feature_flags": feature_flags,
    }


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Scan an Azure subscription and inventory resources for the observability accelerator.",
    )
    parser.add_argument(
        "--subscription-id",
        required=True,
        help="Azure subscription ID to scan.",
    )
    parser.add_argument(
        "--output",
        default="discovery/discovered-resources.json",
        help="Path for the JSON output file (default: discovery/discovered-resources.json).",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)

    print(f"Scanning subscription {args.subscription_id} ...")
    inventory = scan_subscription(args.subscription_id)

    with open(args.output, "w", encoding="utf-8") as fh:
        json.dump(inventory, fh, indent=2)

    summary = inventory["summary"]
    print(f"Scan complete. {summary['total_resources']} resource(s) found "
          f"across {len(summary['regions'])} region(s).")
    print(f"Categories: {', '.join(summary['resource_types_found']) or '(none)'}")
    print(f"Output written to {args.output}")


if __name__ == "__main__":
    main()
