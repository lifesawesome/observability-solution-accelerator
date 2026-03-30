# Diagnostic Settings Module

Deploys `azurerm_monitor_diagnostic_setting` for each discovered Azure resource,
wiring logs and metrics to the central Log Analytics workspace.

## How It Works

The discovery scanner (`scan_subscription.py`) inventories all resources. The
accelerator passes the resource IDs and their appropriate log categories to this
module, which creates one diagnostic setting per resource.

## Trusted Service Bypass

Resources with `publicNetworkAccess: Disabled` still accept diagnostic log
delivery because Azure Monitor is a [trusted Microsoft service](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/diagnostic-settings#destination-limitations).
No private endpoint is needed for diagnostic settings to work.

## Variables

| Variable | Description |
|----------|-------------|
| `workspace_id` | Target Log Analytics workspace |
| `resource_ids` | Map of resource name → ARM resource ID |
| `log_categories_per_resource` | Map of resource name → list of log category names |
| `customer_name` | Used in diagnostic setting name |
