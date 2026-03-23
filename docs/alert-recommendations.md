# Alert Recommendations Catalog

A per-service guide answering **"What should I monitor for [service]?"** — based on Azure Monitor Baseline Alerts (AMBA), Azure Well-Architected Framework, and real-world incident patterns.

---

## How to Use This Document

1. **Identify which Azure services** the customer environment uses
2. **Enable AMBA alert packs** in `infra/variables.tf` via `amba_services`
3. **Tune thresholds** in `amba_thresholds` and `alert_thresholds` to match SLAs
4. **Add custom alerts** for application-specific patterns not covered below

---

## Virtual Machines (Windows & Linux)

| What to Monitor | Metric / KQL Table | Recommended Threshold | Severity | Notes |
|---|---|---|---|---|
| Heartbeat loss | `Heartbeat` | No heartbeat for 5 min | Sev 1 | First signal of VM down |
| CPU utilization | `Perf` (% Processor Time) | > 85% sustained 15 min | Sev 2 | Consider right-sizing if chronic |
| Memory pressure | `Perf` (% Committed Bytes) | > 90% | Sev 2 | Check for memory leaks |
| Disk free space | `Perf` (% Free Space) | < 10% | Sev 2 | Auto-remediate with Clear-DiskSpace runbook |
| Disk IOPS saturation | `Perf` (Disk Transfers/sec) | > 500/sec | Sev 3 | Indicates disk bottleneck |
| Network errors | `Perf` (Network Adapter errors) | > 100 in 30 min | Sev 2 | May indicate NIC issues |
| CPU anomaly | `series_decompose_anomalies` | ML score > 2.0 | Sev 3 | Catches gradual degradation |

**Runbook actions**: Restart-VM, Scale-UpVM, Clear-DiskSpace

---

## Azure SQL Database

| What to Monitor | Metric / KQL Table | Recommended Threshold | Severity | Notes |
|---|---|---|---|---|
| DTU/vCore consumption | `AzureMetrics` (dtu_consumption_percent) | > 85% | Sev 2 | Scale up tier if sustained |
| Deadlocks | `AzureMetrics` (deadlock) | > 0 | Sev 1 | Investigate query patterns immediately |
| Failed connections | `AzureMetrics` (connection_failed) | > 10 per 15 min | Sev 2 | Check firewall, connection pooling |
| Storage usage | `AzureMetrics` (storage_percent) | > 80% | Sev 2 | Plan capacity expansion |
| Long-running queries | `AzureDiagnostics` | > 30 sec | Sev 3 | Optimize or add indexes |
| Blocked queries | `AzureDiagnostics` | > 0 with > 30s wait | Sev 2 | Check locking patterns |

**Key tables**: `AzureMetrics`, `AzureDiagnostics` (requires diagnostic setting on SQL DB)

---

## App Service / Web Apps

| What to Monitor | Metric / KQL Table | Recommended Threshold | Severity | Notes |
|---|---|---|---|---|
| HTTP 5xx errors | `AzureMetrics` (Http5xx) | > 10 per 15 min | Sev 1 | Application errors |
| Response time | `AzureMetrics` (HttpResponseTime) | > 5 sec avg | Sev 2 | User experience impact |
| CPU utilization | `AzureMetrics` (CpuPercentage) | > 85% | Sev 2 | Scale up/out App Service Plan |
| Memory utilization | `AzureMetrics` (MemoryPercentage) | > 85% | Sev 2 | Check for memory leaks |
| HTTP 4xx rate | `AzureMetrics` (Http4xx) | > 100 per 15 min | Sev 3 | May indicate bad clients or routing |
| Health check failures | `AppServiceHTTPLogs` | Status != 200 for /health | Sev 1 | Indicates app not healthy |

**App Insights integration**: Use `AppRequests`, `AppExceptions`, `AppDependencies` for deep diagnostics.

---

## AKS (Azure Kubernetes Service)

| What to Monitor | Metric / KQL Table | Recommended Threshold | Severity | Notes |
|---|---|---|---|---|
| Node CPU | `Perf` (K8SNode cpuUsageNanoCores) | > 80% | Sev 2 | Scale node pool or optimize pods |
| Node memory | `Perf` (K8SNode memoryWorkingSetBytes) | > 80% | Sev 2 | Check pod resource limits |
| OOMKilled containers | `KubePodInventory` (OOMKilled) | > 0 | Sev 1 | Increase container memory limits |
| Pod failures / CrashLoop | `KubePodInventory` (Failed, CrashLoopBackOff) | > 0 | Sev 1 | Investigate pod logs immediately |
| Node NotReady | `KubeNodeInventory` (NotReady) | > 0 | Sev 1 | Check node health, kubelet |
| Pods stuck Pending | `KubePodInventory` (Pending > 10m) | > 0 | Sev 2 | Resource constraints or scheduling issues |
| PV usage | `InsightsMetrics` (pvUsedBytes) | > 85% | Sev 2 | Expand volume or clean data |
| Container restarts | `KubePodInventory` (ContainerRestartCount) | > 5 in 30 min | Sev 2 | Application stability issue |
| API Server latency | `AzureDiagnostics` | > 500ms p99 | Sev 2 | Cluster control plane issues |

**Prerequisites**: Enable Container Insights via `enable_aks = true` in variables.

---

## Azure Databricks

| What to Monitor | Metric / KQL Table | Recommended Threshold | Severity | Notes |
|---|---|---|---|---|
| Job failures | `DatabricksJobs` (runFailed) | > 0 | Sev 1 | Investigate run logs |
| Cluster start errors | `DatabricksClusters` | Error in response | Sev 2 | Check quota, VM availability |
| SQL Warehouse queuing | `DatabricksSQLPermissions` | > 50 queued | Sev 3 | Scale warehouse or optimize queries |
| Notebook execution errors | `DatabricksNotebook` | Errors > 0 | Sev 2 | Check notebook code |
| Long-running jobs | `DatabricksJobs` | Duration > SLA threshold | Sev 3 | Performance regression |

**Key**: Enable diagnostic settings on Databricks workspace to Log Analytics.

---

## Cosmos DB

| What to Monitor | Metric / KQL Table | Recommended Threshold | Severity | Notes |
|---|---|---|---|---|
| RU consumption | `AzureMetrics` (NormalizedRUConsumption) | > 80% | Sev 2 | Scale RUs or optimize queries |
| Rate limiting (429s) | `AzureMetrics` (TotalRequestUnits 429) | > 0 | Sev 1 | Immediate RU scaling needed |
| Availability | `AzureMetrics` (ServiceAvailability) | < 99.99% | Sev 1 | Check region health |
| Server-side latency | `AzureMetrics` (ServerSideLatency) | > 10ms p99 for reads | Sev 2 | Optimize partition keys |
| Metadata requests | `AzureMetrics` (MetadataRequests) | Spike detection | Sev 3 | May indicate connection churn |

---

## Azure Storage (Blob, File, Queue, Table)

| What to Monitor | Metric / KQL Table | Recommended Threshold | Severity | Notes |
|---|---|---|---|---|
| Availability | `AzureMetrics` (Availability) | < 99.9% | Sev 1 | Check regional status |
| Throttling (429/503) | `StorageBlobLogs` | > 10 per 15 min | Sev 2 | Scale to premium or partition |
| E2E latency | `AzureMetrics` (SuccessE2ELatency) | > 100ms avg | Sev 3 | Network or account issues |
| Ingress/Egress anomaly | `AzureMetrics` (Ingress, Egress) | ML anomaly detection | Sev 3 | Potential data exfiltration |
| Capacity growth | `AzureMetrics` (BlobCapacity) | > 80% of quota | Sev 3 | Plan capacity or lifecycle policies |

---

## Key Vault

| What to Monitor | Metric / KQL Table | Recommended Threshold | Severity | Notes |
|---|---|---|---|---|
| Availability | `AzureMetrics` (Availability) | < 99% | Sev 1 | Critical dependency for many services |
| API latency | `AzureMetrics` (ServiceApiLatency) | > 1000ms | Sev 2 | Throttling or region issues |
| Secret/cert expiration | Custom KQL on `AzureDiagnostics` | < 30 days to expiry | Sev 2 | Auto-rotate with Rotate-Secret runbook |
| Unauthorized access | `AzureDiagnostics` (ResultType = Unauthorized) | > 0 | Sev 1 | Potential security incident |
| Throttling | `AzureMetrics` (SaturationShoebox) | > 75% | Sev 2 | Hitting transaction limits |

---

## Event Hubs

| What to Monitor | Metric / KQL Table | Recommended Threshold | Severity | Notes |
|---|---|---|---|---|
| Throttled requests | `AzureMetrics` (ThrottledRequests) | > 0 | Sev 2 | Scale TUs or switch to premium |
| Incoming/Outgoing messages | `AzureMetrics` (IncomingMessages) | Anomaly detection | Sev 3 | Spike may indicate upstream issue |
| Consumer lag | Custom KQL | Growing trend | Sev 2 | Consumers can't keep up |
| Capture failures | `AzureMetrics` | > 0 | Sev 1 | Data loss risk |
| Active connections | `AzureMetrics` (ActiveConnections) | > 80% of limit | Sev 2 | Connection pool exhaustion |

---

## IoT Hub

| What to Monitor | Metric / KQL Table | Recommended Threshold | Severity | Notes |
|---|---|---|---|---|
| Device connection failures | `AzureMetrics` | > 10 per 5 min | Sev 2 | Network or auth issues |
| Device-to-cloud message failures | `AzureMetrics` | > 0 | Sev 1 | Data ingestion at risk |
| Twin update failures | `AzureMetrics` | > 0 | Sev 2 | Configuration propagation issues |
| Quota utilization | `AzureMetrics` (TotalMessages) | > 80% of daily quota | Sev 2 | Plan tier upgrade |
| Connected device count drop | Custom KQL | > 10% drop in 15 min | Sev 1 | Mass disconnect event |

**Relevant for**: Energy/OT customers with field devices reporting via IoT Hub.

---

## Load Balancer

| What to Monitor | Metric / KQL Table | Recommended Threshold | Severity | Notes |
|---|---|---|---|---|
| Health probe status | `AzureMetrics` (DipAvailability) | < 90% | Sev 1 | Backend pool degraded |
| SNAT port exhaustion | `AzureMetrics` (SnatConnectionCount) | Failed allocations > 0 | Sev 2 | Add NAT gateway or outbound rules |
| Data throughput | `AzureMetrics` (ByteCount) | Anomaly detection | Sev 3 | Capacity planning signal |

---

## Network (NSG / Network Watcher)

| What to Monitor | Metric / KQL Table | Recommended Threshold | Severity | Notes |
|---|---|---|---|---|
| NSG flow log gaps | `AzureNetworkAnalytics_CL` | Missing flows > 1 hr | Sev 2 | Compliance visibility gap |
| Denied traffic volume | `AzureNetworkAnalytics_CL` | > 1000 denied/hr from same source | Sev 1 | Potential attack |
| Traffic Analytics anomalies | Traffic Analytics | ML-based | Sev 3 | Unusual geo/IP patterns |

---

## Sentinel (Security)

| What to Monitor | Metric / KQL Table | Recommended Threshold | Severity | Notes |
|---|---|---|---|---|
| Incidents created | `SecurityIncident` | New incidents per hour | Sev varies | Triage required |
| Data connector health | `SentinelHealth` | Connector ingestion gaps | Sev 2 | Blind spots in detection |
| Analytics rule failures | `SentinelHealth` | Rule failures > 0 | Sev 2 | Detection coverage at risk |

---

## Cross-Cutting Recommendations

### For All Services
1. **Always enable diagnostic settings** — Send logs + metrics to Log Analytics
2. **Use `TimeGenerated` filters** — Required for KQL performance
3. **Set up both critical and warning action groups** — Sev 1-2 → PagerDuty/phone; Sev 3-4 → email/Teams
4. **Integrate with ServiceNow** — Use the Logic App templates in `automation/logic-apps/`
5. **Review weekly** — Alert fatigue is real; tune thresholds monthly

### Threshold Tuning Process
1. Deploy with defaults (this accelerator's values)
2. Run for 2 weeks to establish baseline
3. Review alert volume — if > 50/day, tighten thresholds
4. Use `series_decompose_anomalies` for dynamic baselining where possible
5. Document overrides in customer's `.tfvars` file
