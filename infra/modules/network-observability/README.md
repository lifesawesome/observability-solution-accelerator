# Network Observability Module

Deploys network monitoring infrastructure: Network Watcher, NSG Flow Logs, and Traffic Analytics.

## What It Deploys
- Network Watcher (regional)
- Storage Account for NSG flow logs (TLS 1.2, LRS, 30d blob retention)
- NSG Flow Logs (v2, one per NSG in `nsg_ids` map) with Traffic Analytics

## Usage

```hcl
module "network_observability" {
  source = "./modules/network-observability"

  resource_group_name    = "rg-customer-obs"
  location               = "westus2"
  workspace_id           = module.log_analytics.workspace_id
  workspace_customer_id  = module.log_analytics.workspace_customer_id
  customer_name          = "marathon"
  flow_log_retention_days = 90

  nsg_ids = {
    "nsg-web"    = "/subscriptions/.../nsg-web"
    "nsg-app"    = "/subscriptions/.../nsg-app"
    "nsg-data"   = "/subscriptions/.../nsg-data"
  }
}
```

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `nsg_ids` | `map(string)` | `{}` | Map of NSG name to resource ID |
| `flow_log_retention_days` | `number` | `90` | Retention in days |
| `workspace_customer_id` | `string` | — | LA workspace GUID for Traffic Analytics |
