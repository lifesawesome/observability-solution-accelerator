#!/usr/bin/env python3
"""Read discovery output and generate ready-to-deploy Azure Workbook JSON files.

Usage:
    python generate_workbooks.py \
        --workspace-id /subscriptions/.../workspaces/myWorkspace \
        --subscription-id 00000000-0000-0000-0000-000000000000 \
        [--discovery-file discovery/discovered-resources.json] \
        [--output-dir generated-workbooks/] \
        [--customer-name Contoso]
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone

# ---------------------------------------------------------------------------
# Workbook -> resource category mapping
# Each key is a workbook template name (without .json), and the value is a
# dict with:
#   - "triggers": list of discovery resource categories that cause this
#     workbook to be generated (any match is sufficient)
#   - "category": short category label for the manifest
#   - "display_name": human-readable name used in the manifest
# ---------------------------------------------------------------------------
WORKBOOK_RULES: dict[str, dict] = {
    "network-logs": {
        "triggers": [
            "network_security_groups",
            "load_balancers",
            "application_gateways",
            "virtual_networks",
        ],
        "category": "network",
        "display_name": "Network Logs",
    },
    "application-logs": {
        "triggers": [
            "app_services",
            "function_apps",
        ],
        "category": "application",
        "display_name": "Application Logs",
    },
    "vm-logs": {
        "triggers": [
            "virtual_machines",
            "vmss",
        ],
        "category": "vm",
        "display_name": "VM Logs",
    },
    "k8s-logs": {
        "triggers": [
            "aks_clusters",
        ],
        "category": "kubernetes",
        "display_name": "Kubernetes Logs",
    },
    "iot-logs": {
        "triggers": [
            "iot_hubs",
        ],
        "category": "iot",
        "display_name": "IoT Logs",
    },
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _resolve_path(path: str) -> str:
    """Return an absolute path, resolved relative to this script's directory
    when the input is relative."""
    if os.path.isabs(path):
        return path
    # Relative paths are resolved from the repo root (one level above
    # this script's directory).
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(repo_root, path)


def _load_discovery(path: str) -> dict:
    """Load and return the discovery JSON file."""
    abs_path = _resolve_path(path)
    with open(abs_path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def _load_template(name: str) -> dict:
    """Load a workbook template from dashboards/workbooks/{name}.json."""
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    template_path = os.path.join(repo_root, "dashboards", "workbooks", f"{name}.json")
    with open(template_path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def _matching_triggers(rule: dict, discovered_categories: set[str]) -> list[str]:
    """Return the subset of a rule's trigger categories that are present in
    the discovery output."""
    return sorted(set(rule["triggers"]) & discovered_categories)


def _apply_replacements(
    workbook: dict,
    workspace_id: str,
    subscription_id: str,
    customer_name: str | None,
    display_name: str,
) -> dict:
    """Perform placeholder replacement and optional customer-name injection.

    Operates on the serialised JSON string so that replacements are applied
    everywhere (including deeply-nested arrays/objects) without needing to
    walk the tree manually.
    """
    text = json.dumps(workbook)
    text = text.replace("__WORKSPACE_ID__", workspace_id)
    text = text.replace("__SUBSCRIPTION_ID__", subscription_id)
    workbook = json.loads(text)

    # If a customer name is provided, update the first markdown item's title.
    if customer_name:
        for item in workbook.get("items", []):
            if item.get("type") == 1 and "content" in item:
                md = item["content"].get("json", "")
                if md.startswith("# "):
                    # Replace the first line (the heading) with one that
                    # includes the customer name.
                    lines = md.split("\n", 1)
                    original_title = lines[0].lstrip("# ").strip()
                    lines[0] = f"# {customer_name} - {original_title}"
                    item["content"]["json"] = "\n".join(lines)
                break  # only the first markdown item

    return workbook


# ---------------------------------------------------------------------------
# Core generation logic
# ---------------------------------------------------------------------------

def determine_workbooks(discovery: dict) -> list[dict]:
    """Decide which workbooks to generate based on discovered resources.

    Returns a list of dicts, each containing the rule metadata plus the list
    of matched trigger categories.
    """
    discovered_categories = set(discovery.get("resources", {}).keys())
    results: list[dict] = []

    for name, rule in WORKBOOK_RULES.items():
        matched = _matching_triggers(rule, discovered_categories)
        if matched:
            results.append({
                "name": name,
                "rule": rule,
                "triggered_by": matched,
            })

    return results


def generate_workbooks(
    discovery: dict,
    workspace_id: str,
    subscription_id: str,
    output_dir: str,
    customer_name: str | None,
) -> dict:
    """Generate workbook files and a deploy manifest.

    Returns the manifest dict.
    """
    abs_output_dir = _resolve_path(output_dir)
    os.makedirs(abs_output_dir, exist_ok=True)

    selected = determine_workbooks(discovery)

    manifest_workbooks: list[dict] = []

    for entry in selected:
        name = entry["name"]
        rule = entry["rule"]
        triggered_by = entry["triggered_by"]

        display_name = rule["display_name"]
        if customer_name:
            full_display_name = f"{customer_name} - {display_name}"
        else:
            full_display_name = display_name

        # Load, transform, and write the workbook
        template = _load_template(name)
        workbook = _apply_replacements(
            template,
            workspace_id=workspace_id,
            subscription_id=subscription_id,
            customer_name=customer_name,
            display_name=display_name,
        )

        out_path = os.path.join(abs_output_dir, f"{name}.json")
        with open(out_path, "w", encoding="utf-8") as fh:
            json.dump(workbook, fh, indent=2)

        manifest_workbooks.append({
            "name": name,
            "file": f"{name}.json",
            "display_name": full_display_name,
            "category": rule["category"],
            "triggered_by": triggered_by,
        })

    # Build the deployment manifest
    manifest = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "customer_name": customer_name or "",
        "workspace_id": workspace_id,
        "subscription_id": subscription_id,
        "workbooks": manifest_workbooks,
    }

    manifest_path = os.path.join(abs_output_dir, "deploy-manifest.json")
    with open(manifest_path, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)

    return manifest


# ---------------------------------------------------------------------------
# Summary printer
# ---------------------------------------------------------------------------

def print_summary(manifest: dict) -> None:
    """Print a human-readable summary of what was generated."""
    workbooks = manifest.get("workbooks", [])
    customer = manifest.get("customer_name", "")
    customer_label = f" for {customer}" if customer else ""

    print(f"\n{'=' * 60}")
    print(f"Workbook Generation Summary{customer_label}")
    print(f"{'=' * 60}")
    print(f"  Workspace ID   : {manifest['workspace_id']}")
    print(f"  Subscription ID: {manifest['subscription_id']}")
    print(f"  Generated at   : {manifest['generated_at']}")
    print(f"  Workbooks      : {len(workbooks)}")
    print()

    if not workbooks:
        print("  No workbooks were generated (no matching resources found).")
    else:
        for wb in workbooks:
            triggers = ", ".join(wb["triggered_by"])
            print(f"  [{wb['category']}] {wb['display_name']}")
            print(f"         file: {wb['file']}")
            print(f"         triggered by: {triggers}")
            print()

    print(f"{'=' * 60}\n")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate Azure Workbook JSON files from discovery output.",
    )
    parser.add_argument(
        "--discovery-file",
        default="discovery/discovered-resources.json",
        help="Path to the discovery JSON file (default: discovery/discovered-resources.json).",
    )
    parser.add_argument(
        "--workspace-id",
        required=True,
        help="Log Analytics workspace resource ID to embed in workbooks.",
    )
    parser.add_argument(
        "--subscription-id",
        required=True,
        help="Azure subscription ID.",
    )
    parser.add_argument(
        "--output-dir",
        default="generated-workbooks/",
        help="Directory for generated workbook files (default: generated-workbooks/).",
    )
    parser.add_argument(
        "--customer-name",
        default=None,
        help="Optional customer name prepended to workbook titles.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)

    print(f"Loading discovery file: {args.discovery_file}")
    discovery = _load_discovery(args.discovery_file)

    total_resources = discovery.get("summary", {}).get("total_resources", 0)
    categories = discovery.get("summary", {}).get("resource_types_found", [])
    print(f"Discovery contains {total_resources} resource(s) across "
          f"{len(categories)} category/categories: {', '.join(categories) or '(none)'}")

    manifest = generate_workbooks(
        discovery=discovery,
        workspace_id=args.workspace_id,
        subscription_id=args.subscription_id,
        output_dir=args.output_dir,
        customer_name=args.customer_name,
    )

    print_summary(manifest)

    abs_output = _resolve_path(args.output_dir)
    print(f"Output written to: {abs_output}")
    print(f"Deploy manifest  : {os.path.join(abs_output, 'deploy-manifest.json')}")


if __name__ == "__main__":
    main()
