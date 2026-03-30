#!/usr/bin/env python3
"""
Observability Solution Accelerator — One-Command Experience

Customer Journey:
  Step 1 (Discovery Only — no infra, no cost):
    python accelerator.py --subscription-id <SUB_ID> --customer-name <NAME> --discovery-only

    What happens:
      a. Authenticates to Azure (az login required)
      b. Scans every resource in the subscription
      c. Checks network posture (publicNetworkAccess, private endpoints)
      d. Generates workbook JSON dashboards for discovered resource types
      e. Prints a full report: resources, network warnings, recommended flags

  Step 2 (Deploy — creates Log Analytics + wires diagnostics + dashboards):
    python accelerator.py --subscription-id <SUB_ID> --customer-name <NAME> \\
      --resource-group <RG> --skip-discovery

    What happens:
      a. Reads existing discovery output (from Step 1)
      b. Generates Terraform .tfvars with auto-detected feature flags
      c. Generates diagnostic settings config for each discovered resource
      d. Runs terraform init → plan → apply

Prerequisites:
  - Azure CLI authenticated (az login)
  - Python packages: pip install -r discovery/requirements.txt
  - Terraform >= 1.5.0 (for Step 2 only)
"""

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent
DISCOVERY_DIR = ROOT_DIR / "discovery"
INFRA_DIR = ROOT_DIR / "infra"
GENERATED_DIR = ROOT_DIR / "generated-workbooks"


def run_cmd(cmd, description, dry_run=False, capture_stderr=False):
    """Run a shell command and stream output."""
    print(f"\n{'[DRY RUN] ' if dry_run else ''}>>> {description}")
    print(f"    $ {' '.join(cmd)}")
    if dry_run:
        return 0, ""
    stderr_pipe = subprocess.PIPE if capture_stderr else None
    result = subprocess.run(cmd, cwd=str(ROOT_DIR), stderr=stderr_pipe)
    stderr_text = (result.stderr or b"").decode("utf-8", errors="replace") if capture_stderr else ""
    return result.returncode, stderr_text


def step_discover(args):
    """Step 1: Scan Azure subscription(s)."""
    sub_count = len(args.subscription_id_list)
    label = f"{sub_count} subscription(s)" if sub_count > 1 or args.tenant_scan else "subscription"

    print("\n" + "=" * 70)
    print(f"  STEP 1: Discovering resources in {label}")
    print("=" * 70)

    discovery_output = str(DISCOVERY_DIR / "discovered-resources.json")

    # Build the scan command based on mode
    cmd = [sys.executable, str(DISCOVERY_DIR / "scan_subscription.py")]

    if args.tenant_scan:
        cmd.append("--tenant-scan")
    elif len(args.subscription_id_list) > 1:
        cmd.extend(["--subscription-ids", ",".join(args.subscription_id_list)])
    else:
        cmd.extend(["--subscription-id", args.subscription_id_list[0]])

    cmd.extend(["--output", discovery_output])

    rc, stderr = run_cmd(cmd, f"Scanning {label} for resources...", args.dry_run, capture_stderr=True)
    if rc != 0 and not args.dry_run:
        print("\nERROR: Discovery scan failed.")
        if stderr:
            print("\n--- scan_subscription.py error output ---")
            print(stderr.rstrip())
            print("--- end error output ---")
        else:
            print("       Check Azure CLI authentication (run 'az login').")
        return None
    return discovery_output


def step_generate_workbooks(args, discovery_file, workspace_id):
    """Step 2: Generate workbooks from discovery output."""
    print("\n" + "=" * 70)
    print("  STEP 2: Generating workbooks based on discovered resources")
    print("=" * 70)

    output_dir = str(GENERATED_DIR)
    primary_sub = args.subscription_id_list[0] if args.subscription_id_list else "placeholder"
    cmd = [
        sys.executable,
        str(DISCOVERY_DIR / "generate_workbooks.py"),
        "--discovery-file", discovery_file,
        "--workspace-id", workspace_id,
        "--subscription-id", primary_sub,
        "--output-dir", output_dir,
        "--customer-name", args.customer_name,
    ]
    rc, _ = run_cmd(cmd, "Generating workbook templates...", args.dry_run)
    if rc != 0 and not args.dry_run:
        print("ERROR: Workbook generation failed.")
        return None
    return output_dir


def step_generate_tfvars(args, discovery_file, workbook_dir):
    """Step 3: Generate a .tfvars file from discovery output."""
    print("\n" + "=" * 70)
    print("  STEP 3: Generating Terraform .tfvars from discovery")
    print("=" * 70)

    tfvars_path = INFRA_DIR / f"{args.customer_name}.auto.tfvars"

    if args.dry_run:
        print(f"    [DRY RUN] Would generate {tfvars_path}")
        return str(tfvars_path)

    # Read discovery output
    with open(discovery_file) as f:
        discovery = json.load(f)

    flags = discovery.get("feature_flags", {})

    # Build workbook_files map from generated workbooks
    workbook_files = {}
    manifest_path = Path(workbook_dir) / "deploy-manifest.json"
    if manifest_path.exists():
        with open(manifest_path) as f:
            manifest = json.load(f)
        for wb in manifest.get("workbooks", []):
            rel_path = os.path.relpath(
                Path(workbook_dir) / wb["file"], INFRA_DIR
            ).replace("\\", "/")
            workbook_files[wb["display_name"]] = rel_path

    # Build .tfvars content
    lines = [
        f'# Auto-generated by accelerator.py on {datetime.now(timezone.utc).isoformat()}',
        f'# Discovery source: {discovery_file}',
        f'',
        f'subscription_id    = "{args.subscription_id_list[0] if args.subscription_id_list else "placeholder"}"',
        f'customer_name      = "{args.customer_name}"',
        f'resource_group_name = "{args.resource_group}"',
        f'location           = "{args.location}"',
        f'',
        f'# --- Auto-detected feature flags ---',
        f'enable_sentinel             = true',
        f'enable_network_observability = {str(flags.get("enable_network_observability", True)).lower()}',
        f'enable_iot_hub              = {str(flags.get("enable_iot_hub", False)).lower()}',
        f'enable_aks                  = {str(flags.get("enable_aks", False)).lower()}',
        f'enable_amba                 = {str(flags.get("enable_amba", False)).lower()}',
        f'enable_workbooks            = {str(len(workbook_files) > 0).lower()}',
        f'enable_ampls                = {str(flags.get("enable_ampls", False)).lower()}',
        f'',
    ]

    # Add amba_services if AMBA is enabled
    amba_services = flags.get("amba_services", [])
    if amba_services:
        services_str = ", ".join(f'"{s}"' for s in amba_services)
        lines.append(f'amba_services = [{services_str}]')
        lines.append('')

    # Add workbook_files map
    if workbook_files:
        lines.append('workbook_files = {')
        for name, path in workbook_files.items():
            lines.append(f'  "{name}" = "{path}"')
        lines.append('}')
        lines.append('')

    # --- Build diagnostic settings maps from discovered resources ---------
    # Map category -> default log categories for diagnostic settings
    diag_category_defaults = {
        "key_vaults": ["AuditEvent", "AzurePolicyEvaluationDetails"],
        "storage_accounts": ["StorageRead", "StorageWrite", "StorageDelete"],
        "sql_databases": ["SQLSecurityAuditEvents", "AutomaticTuning", "QueryStoreRuntimeStatistics"],
        "cosmos_db": ["DataPlaneRequests", "QueryRuntimeStatistics", "PartitionKeyStatistics"],
        "function_apps": ["FunctionAppLogs"],
        "app_services": ["AppServiceHTTPLogs", "AppServiceConsoleLogs", "AppServiceAppLogs"],
        "iot_hubs": ["Connections", "DeviceTelemetry", "Routes"],
        "event_hubs": ["ArchiveLogs", "OperationalLogs", "AutoScaleLogs"],
        "logic_apps": ["WorkflowRuntime"],
        "network_security_groups": ["NetworkSecurityGroupEvent", "NetworkSecurityGroupRuleCounter"],
        "load_balancers": ["LoadBalancerAlertEvent", "LoadBalancerProbeHealthStatus"],
        "application_gateways": ["ApplicationGatewayAccessLog", "ApplicationGatewayPerformanceLog"],
    }

    diag_resource_ids = {}
    diag_log_categories = {}
    resources = discovery.get("merged_resources") or discovery.get("resources", {})
    for category, res_list in resources.items():
        if category not in diag_category_defaults:
            continue
        for res_entry in res_list:
            # Use a safe key: name with category prefix to avoid collisions
            key = f"{category}-{res_entry['name']}".replace("/", "-")
            diag_resource_ids[key] = res_entry["id"]
            diag_log_categories[key] = diag_category_defaults[category]

    if diag_resource_ids:
        lines.append('# --- Diagnostic Settings (auto-populated from discovery) ---')
        lines.append('diagnostic_resource_ids = {')
        for key, rid in diag_resource_ids.items():
            lines.append(f'  "{key}" = "{rid}"')
        lines.append('}')
        lines.append('')
        lines.append('diagnostic_log_categories = {')
        for key, cats in diag_log_categories.items():
            cats_str = ", ".join(f'"{c}"' for c in cats)
            lines.append(f'  "{key}" = [{cats_str}]')
        lines.append('}')
        lines.append('')

    # --- AMPLS note (if enabled, user must provide subnet/vnet) -----------
    if flags.get("enable_ampls"):
        lines.append('# --- AMPLS: Requires subnet and VNet IDs ---')
        lines.append('# Uncomment and fill in to enable private link connectivity:')
        lines.append('# ampls_subnet_id = "/subscriptions/.../subnets/ampls-subnet"')
        lines.append('# ampls_vnet_id   = "/subscriptions/.../virtualNetworks/your-vnet"')
        lines.append('')

    # --- Network posture summary as comments ------------------------------
    posture = discovery.get("network_posture", {})
    if posture:
        disabled = posture.get("public_access_disabled", [])
        warnings = posture.get("warnings", [])
        if disabled:
            lines.append(f'# --- Network Posture: {len(disabled)} resource(s) have publicNetworkAccess=Disabled ---')
            for d in disabled:
                lines.append(f'#   {d["name"]} ({d["type"]})')
            lines.append('')
        if warnings:
            lines.append(f'# --- Network Warnings ---')
            for w in warnings:
                lines.append(f'#   WARNING: {w["message"]}')
            lines.append('')

    # Write .tfvars
    tfvars_content = "\n".join(lines) + "\n"
    with open(tfvars_path, "w") as f:
        f.write(tfvars_content)

    print(f"    Generated: {tfvars_path}")
    print(f"    Feature flags: {json.dumps(flags, indent=2)}")
    print(f"    Workbooks: {len(workbook_files)} files mapped")
    print(f"    Diagnostic settings: {len(diag_resource_ids)} resources wired")

    return str(tfvars_path)


def step_terraform(args, tfvars_path):
    """Step 4: Run Terraform init + plan + apply."""
    print("\n" + "=" * 70)
    print("  STEP 4: Deploying with Terraform")
    print("=" * 70)

    tfvars_file = os.path.basename(tfvars_path)

    # terraform init
    rc, _ = run_cmd(
        ["terraform", "init"],
        "Initializing Terraform...",
        args.dry_run,
    )
    if rc != 0 and not args.dry_run:
        print("ERROR: terraform init failed.")
        return False

    # terraform plan
    rc, _ = run_cmd(
        ["terraform", "plan", f"-var-file={tfvars_file}", "-out=accelerator.tfplan"],
        "Planning deployment...",
        args.dry_run,
    )
    if rc != 0 and not args.dry_run:
        print("ERROR: terraform plan failed.")
        return False

    if not args.auto_approve:
        print("\n    Review the plan above. Run with --auto-approve to apply automatically.")
        print(f"    Or manually: cd infra && terraform apply accelerator.tfplan")
        return True

    # terraform apply
    rc, _ = run_cmd(
        ["terraform", "apply", "accelerator.tfplan"],
        "Applying infrastructure...",
        args.dry_run,
    )
    if rc != 0 and not args.dry_run:
        print("ERROR: terraform apply failed.")
        return False

    return True


def main():
    parser = argparse.ArgumentParser(
        description="Observability Solution Accelerator — One-Command Deployment",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Discovery only — single subscription
  python accelerator.py --subscription-id <SUB_ID> --customer-name contoso --discovery-only

  # Discovery only — multiple subscriptions
  python accelerator.py --subscription-ids <SUB1>,<SUB2>,<SUB3> --customer-name contoso --discovery-only

  # Discovery only — auto-discover ALL subscriptions in your tenant
  python accelerator.py --tenant-scan --customer-name contoso --discovery-only

  # Full pipeline (discover → generate → plan only)
  python accelerator.py --subscription-id <SUB_ID> --customer-name contoso --resource-group rg-contoso-obs

  # Full pipeline with auto-deploy
  python accelerator.py --subscription-id <SUB_ID> --customer-name contoso --resource-group rg-contoso-obs --auto-approve

  # Skip discovery (use existing discovery file)
  python accelerator.py --subscription-id <SUB_ID> --customer-name contoso --resource-group rg-contoso-obs --skip-discovery
        """,
    )

    sub_group = parser.add_mutually_exclusive_group(required=True)
    sub_group.add_argument("--subscription-id", help="Single Azure subscription ID")
    sub_group.add_argument("--subscription-ids", help="Comma-separated list of subscription IDs")
    sub_group.add_argument("--tenant-scan", action="store_true", default=False, help="Auto-discover and scan ALL subscriptions in the tenant")
    parser.add_argument("--customer-name", required=True, help="Customer name (lowercase, no spaces)")
    parser.add_argument("--resource-group", default=None, help="Azure resource group name (required unless --discovery-only)")
    parser.add_argument("--location", default="westus2", help="Azure region (default: westus2)")
    parser.add_argument("--auto-approve", action="store_true", help="Auto-approve terraform apply")
    parser.add_argument("--dry-run", action="store_true", help="Preview commands without executing")
    parser.add_argument("--skip-discovery", action="store_true", help="Skip discovery, use existing discovered-resources.json")
    parser.add_argument("--discovery-only", action="store_true", help="Only scan resources and generate workbooks (no infra deployment)")
    parser.add_argument("--skip-terraform", action="store_true", dest="discovery_only", help=argparse.SUPPRESS)  # backward compat alias

    args = parser.parse_args()

    # Build subscription ID list from whichever input was used
    if args.subscription_ids:
        args.subscription_id_list = [s.strip() for s in args.subscription_ids.split(",") if s.strip()]
    elif args.subscription_id:
        args.subscription_id_list = [args.subscription_id]
    else:
        args.subscription_id_list = []  # tenant-scan will discover them

    # Validate: --resource-group is required unless --discovery-only
    if not args.discovery_only and not args.resource_group:
        parser.error("--resource-group is required unless --discovery-only is specified.")

    # Default resource-group for discovery-only (used in workspace ID placeholder)
    if not args.resource_group:
        args.resource_group = f"rg-{args.customer_name}-obs"

    mode = "DISCOVERY ONLY" if args.discovery_only else ("DRY RUN" if args.dry_run else "LIVE")
    sub_display = "tenant-wide" if args.tenant_scan else ", ".join(args.subscription_id_list)

    print("=" * 70)
    print("  OBSERVABILITY SOLUTION ACCELERATOR")
    print("=" * 70)
    print(f"  Subscription(s): {sub_display}")
    print(f"  Customer:        {args.customer_name}")
    if not args.discovery_only:
        print(f"  Resource Group:  {args.resource_group}")
        print(f"  Region:          {args.location}")
    print(f"  Mode:            {mode}")
    print("=" * 70)

    # Step 1: Discovery
    if args.skip_discovery:
        discovery_file = str(DISCOVERY_DIR / "discovered-resources.json")
        if not Path(discovery_file).exists() and not args.dry_run:
            print(f"ERROR: --skip-discovery specified but {discovery_file} not found.")
            print("       Run discovery first, or remove --skip-discovery.")
            sys.exit(1)
        print(f"\n  Skipping discovery, using: {discovery_file}")
    else:
        discovery_file = step_discover(args)
        if discovery_file is None:
            sys.exit(1)

    # Determine workspace ID (will be created by Terraform, use placeholder for generation)
    # For tenant-scan: read discovered subscriptions from the output file
    if not args.subscription_id_list and not args.dry_run and Path(discovery_file).exists():
        with open(discovery_file) as f:
            disc = json.load(f)
        # Multi-sub output has 'subscription_ids'; single has 'subscription_id'
        discovered_subs = disc.get("subscription_ids") or []
        if not discovered_subs and disc.get("subscription_id"):
            discovered_subs = [disc["subscription_id"]]
        if discovered_subs:
            args.subscription_id_list = discovered_subs
    primary_sub = args.subscription_id_list[0] if args.subscription_id_list else "placeholder"
    workspace_id = f"/subscriptions/{primary_sub}/resourceGroups/{args.resource_group}/providers/Microsoft.OperationalInsights/workspaces/la-{args.customer_name}-obs"

    # Step 2: Generate workbooks
    workbook_dir = step_generate_workbooks(args, discovery_file, workspace_id)
    if workbook_dir is None:
        sys.exit(1)

    # --- Discovery-only mode: stop here, show report ---------------------
    if args.discovery_only:
        print("\n" + "=" * 70)
        print("  DISCOVERY COMPLETE — No infrastructure was deployed")
        print("=" * 70)

        if not args.dry_run and Path(discovery_file).exists():
            with open(discovery_file) as f:
                discovery = json.load(f)
            summary = discovery.get("summary", {})
            flags = discovery.get("feature_flags", {})

            print(f"\n  Resources found:  {summary.get('total_resources', 0)}")
            print(f"  Regions:          {', '.join(summary.get('regions', [])) or '(none)'}")
            print(f"  Resource types:   {', '.join(summary.get('resource_types_found', [])) or '(none)'}")
            print(f"\n  Auto-detected feature flags:")
            for flag_name in ['enable_aks', 'enable_iot_hub', 'enable_network_observability', 'enable_amba', 'enable_ampls']:
                print(f"    {flag_name}: {flags.get(flag_name, False)}")
            amba = flags.get('amba_services', [])
            if amba:
                print(f"    amba_services: {', '.join(amba)}")

            # Network posture summary
            posture = discovery.get("network_posture", {})
            if posture:
                disabled = posture.get("public_access_disabled", [])
                enabled = posture.get("public_access_enabled", [])
                pe_conns = posture.get("private_endpoint_connections", [])
                warnings = posture.get("warnings", [])

                print(f"\n  Network posture:")
                print(f"    Public access enabled:  {len(enabled)} resource(s)")
                print(f"    Public access disabled: {len(disabled)} resource(s)")
                print(f"    Private endpoints:      {len(pe_conns)} connection(s)")

                if warnings:
                    print(f"\n  {'!' * 60}")
                    print(f"  NETWORK WARNINGS ({len(warnings)}):")
                    for w in warnings:
                        print(f"    - {w['resource']}: {w['message']}")
                    print(f"  {'!' * 60}")
                    print(f"\n  Diagnostic logs will still flow via Azure trusted")
                    print(f"  service bypass. For full private link, deploy with")
                    print(f"  enable_ampls=true and provide subnet/vnet IDs.")

        print(f"\n  Generated files:")
        print(f"    Discovery:  {discovery_file}")
        print(f"    Workbooks:  {workbook_dir}/")

        print(f"\n  To deploy infrastructure (Step 2):")
        print(f"    python accelerator.py \\")
        if len(args.subscription_id_list) == 1:
            print(f"      --subscription-id {args.subscription_id_list[0]} \\")
        elif args.subscription_id_list:
            print(f"      --subscription-ids {','.join(args.subscription_id_list)} \\")
        else:
            print(f"      --tenant-scan \\")
        print(f"      --customer-name {args.customer_name} \\")
        print(f"      --resource-group <RESOURCE_GROUP> \\")
        print(f"      --skip-discovery")
        print("=" * 70)
        return

    # --- Full deploy mode: generate tfvars + run terraform ---------------

    # Step 3: Generate .tfvars
    tfvars_path = step_generate_tfvars(args, discovery_file, workbook_dir)
    if tfvars_path is None:
        sys.exit(1)

    # Step 4: Terraform
    success = step_terraform(args, tfvars_path)
    if not success:
        sys.exit(1)

    print("\n" + "=" * 70)
    print("  ACCELERATOR COMPLETE")
    print("=" * 70)
    print(f"  Discovery output:   {discovery_file}")
    print(f"  Generated workbooks: {workbook_dir}/")
    print(f"  Terraform config:   {tfvars_path}")
    print("=" * 70)


if __name__ == "__main__":
    main()
