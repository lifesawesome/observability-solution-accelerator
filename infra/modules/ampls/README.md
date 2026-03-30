# Azure Monitor Private Link Scope (AMPLS) Module

Deploys an Azure Monitor Private Link Scope to enable private connectivity
between a customer's VNet and Azure Monitor services (Log Analytics, App Insights).

## When to Use

Enable this module (`enable_ampls = true`) when the customer's resources have
`publicNetworkAccess: Disabled` and require end-to-end private telemetry pipelines.

The discovery scanner automatically detects this condition and sets `enable_ampls`
in the generated `.tfvars`.

## What It Creates

| Resource | Purpose |
|----------|---------|
| `azurerm_monitor_private_link_scope` | Groups Azure Monitor resources under a single private link |
| `azurerm_monitor_private_link_scoped_service` | Scopes Log Analytics + App Insights into the AMPLS |
| `azurerm_private_endpoint` | Private endpoint in customer's VNet for AMPLS connectivity |
| `azurerm_private_dns_zone` (optional) | DNS zones for `privatelink.monitor.azure.com`, etc. |
| `azurerm_private_dns_zone_virtual_network_link` | Links DNS zones to the customer's VNet |

## Required Variables

| Variable | Description |
|----------|-------------|
| `workspace_id` | Log Analytics Workspace resource ID |
| `subnet_id` | Subnet ID for the private endpoint |
| `vnet_id` | VNet ID for DNS zone linking |

## Access Modes

- **Open**: Resources accept both public and private ingestion/queries (default, safer)
- **PrivateOnly**: Resources reject all public traffic (full zero-trust)

## DNS Zones Required

When `create_private_dns_zones = true` (default), the module creates and links:

- `privatelink.monitor.azure.com`
- `privatelink.ods.opinsights.azure.com`
- `privatelink.oms.opinsights.azure.com`
- `privatelink.agentsvc.azure-automation.net`
- `privatelink.blob.core.windows.net`

Set `create_private_dns_zones = false` and provide `private_dns_zone_ids` if these
are managed externally (e.g., by a hub networking team).
