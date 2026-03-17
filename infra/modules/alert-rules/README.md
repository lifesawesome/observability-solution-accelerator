# Alert Rules Module

Pre-built alert rules for common infrastructure and application scenarios.

## Included Rules

| Rule | Severity | Type | Description |
|------|----------|------|-------------|
| VM Heartbeat Loss | 1 (Critical) | Log-based | VM stops sending heartbeats for 5+ min |
| App Error Rate Spike | 2 (Warning) | Log-based | Exception count > 50 per 5 min window |
| Disk Space Low | 2 (Warning) | Log-based | Disk free space < 10% |
| Memory Pressure | 2 (Warning) | Log-based | Committed memory > 90% |
| CPU Anomaly | 3 (Info) | ML-based | KQL `series_decompose_anomalies` detection |

## Usage

```hcl
module "alert_rules" {
  source = "./modules/alert-rules"

  resource_group_name = "rg-customer-obs"
  location            = "eastus2"
  workspace_id        = module.log_analytics.workspace_id
  action_group_id     = module.action_groups.critical_action_group_id
  customer_name       = "marathon"
}
```
