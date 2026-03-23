# Log Analytics Spoke Workspace Module

Deploys a Log Analytics workspace for a single customer (spoke) with:
- Windows and Linux Data Collection Rules
- Configurable retention and SKU
- Basic Logs support for cost optimization

## Usage

```hcl
module "log_analytics" {
  source = "./modules/log-analytics-spoke"

  resource_group_name = "rg-customer-obs"
  location            = "westus2"
  workspace_name      = "la-customer-obs"
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = { project = "observability" }
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `workspace_name` | Workspace name | `string` | — |
| `resource_group_name` | Resource group | `string` | — |
| `location` | Azure region | `string` | — |
| `sku` | `PerGB2018` or `CapacityReservation` | `string` | `PerGB2018` |
| `capacity_reservation_level` | GB/day for CapacityReservation | `number` | `100` |
| `retention_in_days` | Interactive retention | `number` | `90` |
| `tags` | Resource tags | `map(string)` | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `workspace_id` | Workspace resource ID |
| `workspace_name` | Workspace name |
| `workspace_customer_id` | Workspace customer ID (for agents) |
| `dcr_windows_perf_id` | Windows DCR ID |
| `dcr_linux_perf_id` | Linux DCR ID |
