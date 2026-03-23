# AMBA (Azure Monitor Baseline Alerts) Module

Deploys service-specific alert packs aligned with Azure Monitor best practices. Customers select which Azure services to monitor via `amba_services`, and all thresholds are tunable via `thresholds`.

## Supported Services

| Service | ID | Alert Count | Alerts |
|---------|-----|-------------|--------|
| Virtual Machines | `vm` | 3 | CPU high, Disk IOPS saturation, Network errors |
| Azure SQL Database | `sql` | 3 | DTU/CPU high, Deadlocks, Failed connections |
| App Service | `appservice` | 3 | HTTP 5xx errors, Response time, CPU high |
| AKS (Kubernetes) | `aks` | 3 | Node CPU, Node memory, Pod failures/CrashLoop |
| Azure Storage | `storage` | 2 | Availability, Throttling |
| Key Vault | `keyvault` | 2 | Availability, Latency |
| Event Hubs | `eventhub` | 1 | Throttled requests |
| Cosmos DB | `cosmosdb` | 2 | RU consumption, Rate limiting (429) |
| Databricks | `databricks` | 3 | Job failures, Cluster errors, Warehouse queuing |
| Load Balancer | `loadbalancer` | 2 | Health probe down, SNAT exhaustion |

**Total: Up to 24 alert rules** across 10 service packs.

## Usage

```hcl
module "amba_alerts" {
  source = "./modules/amba-alerts"

  resource_group_name      = "rg-customer-obs"
  location                 = "westus2"
  workspace_id             = module.log_analytics.workspace_id
  critical_action_group_id = module.action_groups.critical_action_group_id
  warning_action_group_id  = module.action_groups.warning_action_group_id
  customer_name            = "marathon"

  # Pick only the services this customer uses
  amba_services = ["vm", "sql", "appservice", "aks", "databricks"]

  # Tune thresholds per customer
  thresholds = {
    vm_cpu_percent            = 90    # default: 85
    sql_dtu_percent           = 80    # default: 85
    aks_node_cpu_percent      = 75    # default: 80
    appservice_response_time_sec = 3  # default: 5
  }
}
```

## Thresholds

| Threshold | Default | Description |
|-----------|---------|-------------|
| `vm_cpu_percent` | 85 | VM CPU utilization warning |
| `vm_disk_iops` | 500 | Disk transfers/sec saturation |
| `sql_dtu_percent` | 85 | SQL DTU/vCore utilization |
| `sql_failed_connections` | 10 | Failed SQL connections per 15min |
| `appservice_http_5xx_count` | 10 | HTTP 5xx errors per 15min |
| `appservice_response_time_sec` | 5 | Average response time in seconds |
| `aks_node_cpu_percent` | 80 | AKS node CPU utilization |
| `aks_node_memory_percent` | 80 | AKS node memory utilization |
| `storage_throttle_count` | 10 | Storage throttle events per 15min |
| `cosmosdb_ru_percent` | 80 | Cosmos DB RU consumption |
