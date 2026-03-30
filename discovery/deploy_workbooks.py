#!/usr/bin/env python3
"""Deploy generated Azure Workbooks to a resource group using the Azure CLI.

Reads the deploy-manifest.json produced by generate_workbooks.py and runs
``az monitor workbook create`` for each workbook listed.

Usage:
    python deploy_workbooks.py \
        --resource-group rg-observability \
        [--manifest generated-workbooks/deploy-manifest.json] \
        [--location westus2] \
        [--dry-run]
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import uuid

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _az_cmd() -> str:
    """Return the correct az CLI command name for the current platform."""
    # On Windows, 'az' is actually 'az.cmd'; shutil.which handles PATH lookup
    return shutil.which("az") or "az"

def _resolve_path(path: str) -> str:
    """Return an absolute path, resolved relative to the repo root when the
    input is relative."""
    if os.path.isabs(path):
        return path
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(repo_root, path)


def _load_manifest(path: str) -> dict:
    """Load and return the deployment manifest."""
    abs_path = _resolve_path(path)
    with open(abs_path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def _load_workbook_content(manifest_dir: str, filename: str) -> str:
    """Load a generated workbook JSON file and return it as a string."""
    wb_path = os.path.join(manifest_dir, filename)
    with open(wb_path, "r", encoding="utf-8") as fh:
        return fh.read()


# ---------------------------------------------------------------------------
# Deployment
# ---------------------------------------------------------------------------

def deploy_workbook(
    workbook_entry: dict,
    manifest_dir: str,
    resource_group: str,
    location: str,
    subscription_id: str,
    dry_run: bool,
) -> bool:
    """Deploy a single workbook via the ARM REST API (``az rest``).

    Uses ``az rest --method PUT`` to avoid Windows command-line length limits
    and the need for the ``application-insights`` CLI extension.

    Returns True on success (or dry-run), False on failure.
    """
    name = workbook_entry["name"]
    display_name = workbook_entry["display_name"]
    filename = workbook_entry["file"]
    category = workbook_entry.get("category", "workbook")

    # Each workbook needs a unique GUID as its resource name
    workbook_guid = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"observability-accelerator.{name}"))

    # Build the path to the workbook content file
    wb_file_path = os.path.join(manifest_dir, filename)

    # Read the serialised workbook content
    workbook_content = _load_workbook_content(manifest_dir, filename)

    # ARM resource URI
    resource_url = (
        f"https://management.azure.com/subscriptions/{subscription_id}"
        f"/resourceGroups/{resource_group}"
        f"/providers/Microsoft.Insights/workbooks/{workbook_guid}"
        f"?api-version=2022-04-01"
    )

    # ARM request body
    body = {
        "location": location,
        "kind": "shared",
        "properties": {
            "displayName": display_name,
            "serializedData": workbook_content,
            "category": category,
            "sourceId": f"/subscriptions/{subscription_id}/resourceGroups/{resource_group}",
        },
    }

    if dry_run:
        print(f"  [DRY RUN] PUT {resource_url}")
        print(f"            displayName: {display_name}")
        print(f"            category: {category}")
        print(f"            source: @{wb_file_path}")
        return True

    print(f"  Deploying {display_name} ({workbook_guid}) ...")

    # Write body to a temp file to avoid command-line length limits on Windows
    tmp_fd, tmp_path = tempfile.mkstemp(suffix=".json", prefix="wb_")
    try:
        with os.fdopen(tmp_fd, "w", encoding="utf-8") as fh:
            json.dump(body, fh)

        cmd = [
            _az_cmd(), "rest",
            "--method", "PUT",
            "--url", resource_url,
            "--body", f"@{tmp_path}",
        ]

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
        )
        print(f"    Success: {display_name}")
        return True
    except subprocess.CalledProcessError as exc:
        print(f"    FAILED: {display_name}", file=sys.stderr)
        print(f"    stderr: {exc.stderr.strip()}", file=sys.stderr)
        return False
    except FileNotFoundError:
        print(
            "    ERROR: 'az' CLI not found. Please install the Azure CLI: "
            "https://learn.microsoft.com/en-us/cli/azure/install-azure-cli",
            file=sys.stderr,
        )
        return False
    finally:
        os.unlink(tmp_path)


def deploy_all(
    manifest: dict,
    manifest_dir: str,
    resource_group: str,
    location: str,
    dry_run: bool,
) -> int:
    """Deploy all workbooks in the manifest.

    Returns the number of failures (0 means all succeeded).
    """
    workbooks = manifest.get("workbooks", [])
    subscription_id = manifest.get("subscription_id", "")

    if not workbooks:
        print("No workbooks to deploy.")
        return 0

    mode_label = " (dry run)" if dry_run else ""
    print(f"\nDeploying {len(workbooks)} workbook(s) to "
          f"resource group '{resource_group}' in '{location}'{mode_label}:\n")

    failures = 0
    for entry in workbooks:
        ok = deploy_workbook(
            workbook_entry=entry,
            manifest_dir=manifest_dir,
            resource_group=resource_group,
            location=location,
            subscription_id=subscription_id,
            dry_run=dry_run,
        )
        if not ok:
            failures += 1

    print()
    succeeded = len(workbooks) - failures
    print(f"Results: {succeeded}/{len(workbooks)} succeeded, {failures} failed.")
    return failures


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Deploy generated Azure Workbooks using the Azure CLI.",
    )
    parser.add_argument(
        "--manifest",
        default="generated-workbooks/deploy-manifest.json",
        help="Path to the deploy manifest (default: generated-workbooks/deploy-manifest.json).",
    )
    parser.add_argument(
        "--resource-group",
        required=True,
        help="Azure resource group to deploy workbooks into.",
    )
    parser.add_argument(
        "--location",
        default="westus2",
        help="Azure region for the workbook resources (default: westus2).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        default=False,
        help="Print commands without executing them.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)

    manifest_path = _resolve_path(args.manifest)
    manifest_dir = os.path.dirname(manifest_path)

    print(f"Loading manifest: {manifest_path}")
    manifest = _load_manifest(args.manifest)

    customer = manifest.get("customer_name", "")
    if customer:
        print(f"Customer: {customer}")

    failures = deploy_all(
        manifest=manifest,
        manifest_dir=manifest_dir,
        resource_group=args.resource_group,
        location=args.location,
        dry_run=args.dry_run,
    )

    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
