# Architecture Overview

## Design Principles

1. **Hub-Spoke Isolation** — Each customer gets a dedicated Log Analytics workspace (spoke). The managed service provider operates a hub workspace for aggregated cross-customer views via Azure Lighthouse.
2. **Monitor Everything by Default** — Azure Policy auto-deploys Azure Monitor Agent (AMA) with Data Collection Rules (DCRs) to every VM and Arc-connected server.
3. **OTel-First Instrumentation** — Applications use OpenTelemetry SDKs with the Azure Monitor Exporter, keeping vendor neutrality while feeding Application Insights.
4. **Security-Embedded** — Sentinel is onboarded to the same Log Analytics workspace, avoiding duplicate ingestion and enabling unified KQL queries across operational and security data.
5. **Proactive over Reactive** — Dynamic thresholds, KQL anomaly detection, and Fabric Data Activator replace static thresholds wherever possible.

---

## Logical Architecture

```text
┌────────────────────────────────────────────────────────────────────┐
│  Layer 5: Action & Automation                                      │
│  ┌──────────────┐ ┌──────────────────┐ ┌────────────────────────┐ │
│  │ ServiceNow   │ │ Logic Apps       │ │ Azure Automation       │ │
│  │ ITSM / CMDB  │ │ Bi-directional   │ │ Runbooks (L0 healing)  │ │
│  └──────┬───────┘ └────────┬─────────┘ └────────────┬───────────┘ │
├─────────┼──────────────────┼────────────────────────┼─────────────┤
│  Layer 4: Visualization                                            │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────┐ │
│  │ Azure        │ │ Managed      │ │ Power BI     │ │ Sentinel │ │
│  │ Workbooks    │ │ Grafana      │ │ (OT/Fabric)  │ │ Workbooks│ │
│  └──────────────┘ └──────────────┘ └──────────────┘ └──────────┘ │
├────────────────────────────────────────────────────────────────────┤
│  Layer 3: Intelligence                                             │
│  ┌──────────────────────────────┐  ┌─────────────────────────────┐│
│  │ Azure Monitor                │  │ Microsoft Sentinel          ││
│  │ • Dynamic thresholds          │  │ • Analytics rules (sched)  ││
│  │ • Smart Detection (AI)        │  │ • UEBA anomaly detection   ││
│  │ • KQL series_decompose        │  │ • Fusion (multi-stage)     ││
│  │ • Copilot for Operations      │  │ • Threat Intelligence      ││
│  └──────────────────────────────┘  └─────────────────────────────┘│
│  ┌──────────────────────────────┐  ┌─────────────────────────────┐│
│  │ Fabric Data Activator        │  │ Azure ML                   ││
│  │ • Pattern-based triggers      │  │ • MTTF prediction models   ││
│  │ • No static alert thresholds  │  │ • Anomaly detection        ││
│  └──────────────────────────────┘  └─────────────────────────────┘│
├───────────────────────────────┬────────────────────────────────────┤
│  Layer 2a: IT Data Platform   │  Layer 2b: OT Data Platform       │
│  ┌─────────────────────────┐  │  ┌──────────────────────────────┐ │
│  │ Log Analytics Workspace │  │  │ Microsoft Fabric             │ │
│  │ (Hub-Spoke)             │  │  │ • KQL Database (Eventhouse)  │ │
│  │ + Sentinel onboarded    │  │  │ • Lakehouse (cold path)      │ │
│  │ + App Insights linked   │  │  │ • Data Activator             │ │
│  └─────────────────────────┘  │  └──────────────────────────────┘ │
├───────────────────────────────┼────────────────────────────────────┤
│  Layer 1a: IT Data Plane      │  Layer 1b: OT/IoT Data Plane      │
│  ┌─────────────────────────┐  │  ┌──────────────────────────────┐ │
│  │ Azure Monitor Agent     │  │  │ Azure IoT Hub               │ │
│  │ + DCRs (policy-driven)  │  │  │ + IoT Edge runtime          │ │
│  │ Azure Arc (hybrid)      │  │  │ Defender for IoT            │ │
│  │ OpenTelemetry SDKs      │  │  │ OPC-UA / Modbus / MQTT      │ │
│  │ Diagnostic Settings     │  │  │ Protocol translation        │ │
│  └─────────────────────────┘  │  └──────────────────────────────┘ │
└───────────────────────────────┴────────────────────────────────────┘
```

---

## Hub-Spoke Log Analytics Topology

```text
┌─────────────────────────────────────────────────────────────┐
│              Managed Service Hub (Your Tenant)              │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Hub Log Analytics Workspace                          │  │
│  │  • Cross-workspace KQL:  workspace('spoke-A').Table   │  │
│  │  • Aggregated MTTI/MTTR workbooks                     │  │
│  │  • Azure Lighthouse delegated access                  │  │
│  └───────────────────────────────────────────────────────┘  │
└──────────┬──────────────────┬──────────────────┬────────────┘
           │                  │                  │
  ┌────────▼─────┐   ┌───────▼───────┐   ┌──────▼──────────┐
  │ Spoke A      │   │ Spoke B       │   │ Spoke C         │
  │ Marathon     │   │ Customer B    │   │ Customer C      │
  │              │   │               │   │                 │
  │ LA Workspace │   │ LA Workspace  │   │ LA Workspace    │
  │ + Sentinel   │   │ + Sentinel    │   │ + Sentinel      │
  │ + App Ins.   │   │ + App Ins.    │   │ + App Ins.      │
  │ + DCRs       │   │ + DCRs        │   │ + DCRs          │
  └──────────────┘   └───────────────┘   └─────────────────┘
```

**Why hub-spoke?**
- **Data sovereignty** — Customer data stays in their workspace / subscription.  
- **Cost clarity** — Each spoke has its own commitment tier and retention settings.  
- **Blast radius** — A runaway ingestion spike in one spoke doesn't affect others.  
- **Lighthouse** — The hub tenant gets `Monitoring Reader` + `Log Analytics Reader` + `Sentinel Reader` roles via delegated resource management, zero standing admin access.

---

## Data Flow: IT Path

```
On-prem Server ──(Azure Arc)──► ARM projection
                                    │
Azure VM ──────────────────────────►│
                                    ▼
                        Azure Policy: auto-deploy AMA + DCR
                                    │
                                    ▼
                        Log Analytics Workspace (Spoke)
                          ├── Perf counters
                          ├── Event logs / Syslog
                          ├── Heartbeat
                          └── Custom logs
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
              Alert Rules      Sentinel       Workbooks
            (dynamic threshold)  (analytics)   (visualization)
                    │               │
                    ▼               ▼
              Action Groups    Sentinel SOAR
                    │               │
                    ▼               ▼
              ServiceNow ITSM    Logic Apps → Automation Runbook
```

## Data Flow: OT/IoT Path

```
OT Device (PLC/SCADA) ──(OPC-UA/Modbus)──► IoT Edge ──► Azure IoT Hub
                                                             │
                                                    ┌────────┴────────┐
                                                    ▼                 ▼
                                             Event Hub          IoT Hub routes
                                                    │            (built-in)
                                            ┌───────┼────────┐
                                            ▼       ▼        ▼
                                      Fabric KQL  Lakehouse  Data Activator
                                      (real-time) (cold)     (proactive)
                                            │
                                            ▼
                                       Power BI Dashboard
```

---

## Terraform Module Map

| Module | Purpose | Key Resources |
|--------|---------|---------------|
| `log-analytics-spoke` | Customer workspace + DCRs | `azurerm_log_analytics_workspace`, `azurerm_monitor_data_collection_rule` |
| `app-insights` | Workspace-based Application Insights | `azurerm_application_insights` |
| `sentinel` | SIEM/SOAR onboarding + analytics rules | `azurerm_sentinel_log_analytics_workspace_onboarding`, `azurerm_sentinel_alert_rule_scheduled` |
| `alert-rules` | Dynamic threshold + log-based alerts | `azurerm_monitor_scheduled_query_rules_alert_v2`, `azurerm_monitor_metric_alert` |
| `action-groups` | Notification routing (email, webhook) | `azurerm_monitor_action_group` |
| `policy-initiative` | Enforce AMA + DCR deployment | `azurerm_subscription_policy_assignment` |
| `lighthouse` | Cross-tenant delegated access | `azurerm_lighthouse_definition`, `azurerm_lighthouse_assignment` |
| `iot-hub` | IoT device telemetry ingestion | `azurerm_iothub`, `azurerm_eventhub_namespace` |
| `network-observability` | NSG flow logs + Network Watcher | `azurerm_network_watcher`, `azurerm_storage_account` |
| `fabric-workspace` | *(Placeholder)* Fabric KQL + Lakehouse | Manual / REST API setup |

---

## Security Model

| Concern | Control |
|---------|---------|
| Managed service access | Azure Lighthouse — no credentials stored, JIT eligible |
| Customer data isolation | Dedicated spoke workspace per customer |
| Secret management | Terraform state encrypted; no secrets in code |
| Agent auth | System-assigned managed identity for AMA |
| SIEM | Sentinel on same workspace — zero-copy security analytics |
| Compliance | Azure Policy enforces DCR association; audit mode first, then deny |
| IoT | IoT Hub SAS separated (send vs listen); Defender for IoT agentless |

---

## Deployment Strategy

1. **`terraform init`** — initialize providers and backend
2. **`terraform plan -var-file=customer.tfvars`** — preview changes per customer
3. **`terraform apply`** — deploy spoke infrastructure
4. **Post-deploy** — manual Fabric workspace setup (until Terraform provider available)
5. **Azure Policy** — auto-enrolls new VMs / Arc servers into monitoring
