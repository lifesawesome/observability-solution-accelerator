# Observability Solution Accelerator

End-to-end Intelligent Operations framework built on Azure Monitor, Microsoft Sentinel, Microsoft Fabric, and ServiceNow — spanning IT infrastructure, applications, OT/IoT, and security.

## What This Is

A **reusable, multi-tenant solution accelerator** that gives each customer a turnkey observability stack:

- **IT Observability**: Azure Monitor + Log Analytics + Application Insights (OpenTelemetry)
- **OT/IoT Observability**: Azure IoT Hub + IoT Edge + Defender for IoT + Microsoft Fabric
- **Security Observability**: Microsoft Sentinel (SIEM/SOAR/UEBA)
- **Workflow Automation**: ServiceNow ITSM + Azure Automation + Logic Apps
- **AI/Proactive Intelligence**: Copilot for Operations, Predictive Maintenance, Data Activator

## Architecture

```text
┌────────────────────────────────────────────────────────────────┐
│  Layer 5: Action & Automation                                  │
│  ServiceNow (ITSM/CMDB) ◄──► Logic Apps ◄──► Automation       │
├────────────────────────────────────────────────────────────────┤
│  Layer 4: Visualization                                        │
│  Azure Workbooks │ Power BI │ Managed Grafana │ Sentinel WB    │
├────────────────────────────────────────────────────────────────┤
│  Layer 3: Intelligence                                         │
│  Dynamic Thresholds │ Smart Detection │ Copilot │ ML (MTTF)   │
│  KQL Anomaly Detection │ Log Clustering │ Data Activator       │
├──────────────────────────────┬─────────────────────────────────┤
│  Layer 2a: IT Data Platform  │  Layer 2b: OT Data Platform    │
│  Log Analytics (Hub-Spoke)   │  Microsoft Fabric              │
│  + Sentinel                  │  KQL DB + Lakehouse            │
│  + App Insights              │                                │
├──────────────────────────────┼─────────────────────────────────┤
│  Layer 1a: IT Data Plane     │  Layer 1b: OT/IoT Data Plane  │
│  AMA + DCR (Azure Policy)    │  IoT Edge + IoT Hub           │
│  Azure Arc (hybrid)          │  Defender for IoT             │
│  OpenTelemetry SDK           │  OPC-UA / Modbus / MQTT       │
│  Diagnostic Settings         │                               │
└──────────────────────────────┴─────────────────────────────────┘
```

## Hub-Spoke Topology

Each customer gets an isolated spoke workspace. Your managed service hub provides aggregated views via Azure Lighthouse.

```text
┌───────────────────────────────────────────────────────┐
│           MANAGED SERVICE HUB (Your Tenant)           │
│  ┌─────────────────────────────────────────────────┐  │
│  │  Hub Log Analytics Workspace                    │  │
│  │  • Cross-workspace KQL queries                  │  │
│  │  • Aggregated MTTI/MTTR dashboards              │  │
│  │  • Azure Lighthouse delegated access            │  │
│  └─────────────────────────────────────────────────┘  │
└──────────────┬──────────────┬──────────────┬──────────┘
               │              │              │
    ┌──────────▼───┐   ┌──────▼───────┐   ┌─▼────────────┐
    │ Customer A   │   │ Customer B   │   │ Customer C   │
    │ Spoke WS     │   │ Spoke WS     │   │ Spoke WS     │
    │ + Sentinel   │   │ + Sentinel   │   │ + Sentinel   │
    │ + App Ins.   │   │ + App Ins.   │   │ + App Ins.   │
    └──────────────┘   └──────────────┘   └──────────────┘
```

## Repository Structure

| Folder | Contents |
|--------|----------|
| `infra/` | Terraform root config (`main.tf`, `variables.tf`, `outputs.tf`, `providers.tf`) |
| `infra/modules/` | Terraform modules for each Azure component |
| `dashboards/workbooks/` | Pre-built Azure Workbook JSON templates |
| `dashboards/powerbi/` | Power BI templates for OT observability |
| `automation/runbooks/` | Azure Automation runbooks for L0 remediation |
| `automation/logic-apps/` | Logic App templates for ServiceNow integration |
| `policies/` | Azure Policy definitions and initiatives |
| `docs/` | Architecture docs, onboarding playbook, instrumentation guides |
| `templates/` | Assessment templates (gap analysis, partner matrix) |

## Quick Start — Customer Deployment Guide

This accelerator is a **scaffold template**. Customers never edit module code — they only create a single `.tfvars` file with their values and run `terraform apply`.

### Prerequisites

| Requirement | Details |
|------------|---------|
| **Terraform** | >= 1.5.0 ([install guide](https://developer.hashicorp.com/terraform/install)) |
| **Azure CLI** | Latest version ([install guide](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)) |
| **Azure Subscription** | With **Contributor** + **User Access Administrator** roles |
| **Resource Group** | Pre-created in your target region, or permissions to create one |

### Step 1: Clone and Create Your Config

```bash
git clone <repo-url>
cd observability-solution-accelerator/infra
cp terraform.tfvars.example <your-company>.tfvars
```

### Step 2: Edit Your `.tfvars` File

Open `<your-company>.tfvars` and fill in the values below. **Only 3 fields are required** — everything else has working defaults.

#### Required Settings (you MUST set these)

| Setting | Type | Example | Description |
|---------|------|---------|-------------|
| `subscription_id` | string | `"a1b2c3d4-..."` | Your Azure subscription ID. Find it with `az account show --query id -o tsv` |
| `customer_name` | string | `"contoso"` | Lowercase alphanumeric + hyphens only. Used to name all resources (e.g., `la-contoso-obs`, `ai-contoso-webapp`) |
| `resource_group_name` | string | `"rg-contoso-obs"` | The resource group to deploy into. Must exist before running `terraform apply` |

#### Optional Settings (with defaults that work out of the box)

**Region & Workspace:**

| Setting | Default | Description |
|---------|---------|-------------|
| `location` | `"westus2"` | Azure region. All resources deploy here. Alternatives: `swedencentral`, `eastus`, etc. |
| `workspace_sku` | `"PerGB2018"` | Log Analytics SKU. Use `"CapacityReservation"` for high-volume (>100 GB/day) |
| `workspace_retention_days` | `90` | Log retention in days (30–730). Set higher for compliance (e.g., 365) |

**Feature Toggles (turn modules on/off):**

| Setting | Default | When to Enable |
|---------|---------|----------------|
| `enable_sentinel` | `true` | Disable only if you already have Sentinel elsewhere |
| `enable_network_observability` | `true` | Disable if you don't need NSG flow logs / Traffic Analytics |
| `enable_iot_hub` | `false` | Enable if you have OT/IoT devices (PLCs, SCADA, RTUs) |
| `enable_amba` | `false` | Enable for AMBA service-specific alert packs (SQL, AKS, Databricks, etc.) |
| `enable_aks` | `false` | Enable if you run AKS clusters (requires `aks_cluster_id`) |
| `enable_lighthouse` | `false` | Enable if managed by an MSP partner (requires tenant/principal IDs) |

**Applications — App Insights (one instance per app):**

| Setting | Default | Example |
|---------|---------|---------|
| `app_insights_apps` | `[]` | `["webapp", "api", "worker"]` — creates `ai-contoso-webapp`, `ai-contoso-api`, etc. |

**Alerts & Notifications:**

| Setting | Default | Description |
|---------|---------|-------------|
| `alert_email_recipients` | `[]` | Email addresses for alert notifications, e.g., `["noc@contoso.com"]` |
| `servicenow_webhook_uri` | `""` | ServiceNow webhook URL for ITSM integration (leave blank to skip) |
| `alert_thresholds` | See below | Tune core alert thresholds |

Default `alert_thresholds` (override any value you want):
```hcl
alert_thresholds = {
  disk_free_percent         = 10    # Alert when disk < 10% free
  memory_committed_percent  = 90    # Alert when memory > 90%
  app_exception_count       = 50    # Alert when exceptions > 50 per 5min
  cpu_anomaly_score         = 2.0   # ML anomaly sensitivity (lower = more sensitive)
  heartbeat_missing_minutes = 5     # Alert when VM heartbeat lost for 5min
}
```

**AMBA Service Alert Packs (requires `enable_amba = true`):**

| Setting | Default | Description |
|---------|---------|-------------|
| `amba_services` | `["vm"]` | Services to monitor. Options: `vm`, `sql`, `appservice`, `aks`, `storage`, `keyvault`, `eventhub`, `cosmosdb`, `databricks`, `loadbalancer` |
| `amba_thresholds` | See below | Tune per-service alert thresholds |

Default `amba_thresholds`:
```hcl
amba_thresholds = {
  vm_cpu_percent               = 85   # VM CPU warning
  vm_disk_iops                 = 500  # Disk IOPS saturation
  sql_dtu_percent              = 85   # SQL DTU/vCore utilization
  sql_failed_connections       = 10   # Failed SQL connections per 15min
  appservice_http_5xx_count    = 10   # HTTP 5xx errors per 15min
  appservice_response_time_sec = 5    # Average response time threshold
  aks_node_cpu_percent         = 80   # AKS node CPU warning
  aks_node_memory_percent      = 80   # AKS node memory warning
  storage_throttle_count       = 10   # Storage throttle events per 15min
  cosmosdb_ru_percent          = 80   # Cosmos DB RU consumption
}
```

**AKS Monitoring (requires `enable_aks = true`):**

| Setting | Default | Description |
|---------|---------|-------------|
| `aks_cluster_id` | `""` | Full resource ID of your AKS cluster, e.g., `/subscriptions/.../managedClusters/my-cluster` |

**IoT Hub (requires `enable_iot_hub = true`):**

| Setting | Default | Description |
|---------|---------|-------------|
| `iot_hub_sku` | `"S1"` | IoT Hub tier |
| `iot_hub_capacity` | `1` | Number of IoT Hub units |

**Lighthouse / MSP (requires `enable_lighthouse = true`):**

| Setting | Default | Description |
|---------|---------|-------------|
| `lighthouse_hub_tenant_id` | `""` | Managing partner's Azure AD tenant ID |
| `lighthouse_hub_principal_id` | `""` | Service principal ID for delegated access |

**Network (requires `enable_network_observability = true`):**

| Setting | Default | Description |
|---------|---------|-------------|
| `nsg_ids` | `{}` | Map of NSG name → resource ID for flow logs, e.g., `{ "web-nsg" = "/subscriptions/.../nsgs/web-nsg" }` |
| `flow_log_retention_days` | `90` | Flow log retention in days |

**Tags:**

| Setting | Default | Description |
|---------|---------|-------------|
| `tags` | `{}` | Tags applied to all resources. Example: `{ environment = "production", cost_center = "IT-OPS" }` |

### Step 3: Deploy

```bash
# Login to Azure
az login

# Create the resource group (if it doesn't exist)
az group create --name rg-contoso-obs --location westus2

# Initialize Terraform (downloads providers + modules)
cd infra/
terraform init

# Preview what will be created (no resources deployed yet)
terraform plan -var-file=contoso.tfvars

# Deploy the full observability stack
terraform apply -var-file=contoso.tfvars
```

### Step 4: Verify (optional)

```bash
# Run the smoke test to validate deployment
cd ..
chmod +x tests/smoke-test.sh
./tests/smoke-test.sh rg-contoso-obs contoso --sentinel
```

### What Gets Deployed Automatically

With just the 3 required values + defaults, you get:

| Resource | Count | Description |
|----------|-------|-------------|
| Log Analytics Workspace | 1 | Central log store with 90-day retention |
| Data Collection Rules | 2 | Windows + Linux performance counters |
| Microsoft Sentinel | 1 | SIEM onboarded to the workspace |
| Action Groups | 3 | Critical, Warning, Automation notification channels |
| Alert Rules | 5 | Heartbeat loss, app errors, disk, memory, CPU anomaly |
| Azure Policy Assignments | 6 | Auto-deploy AMA + associate DCRs to all VMs |
| Network Watcher | 1 | Network observability baseline |

### Post-Deploy Steps (Optional)

| Task | How | When |
|------|-----|------|
| Import Azure Workbooks | Upload JSON from `dashboards/workbooks/` via Azure Portal | After deploy |
| Deploy Logic Apps | Use ARM templates from `automation/logic-apps/` | If using ServiceNow |
| Register Runbooks | Import `.ps1` from `automation/runbooks/` into Azure Automation | For L0 auto-remediation |
| Instrument Apps | Follow guides in `docs/instrumentation/` (Java, .NET, Node.js, Python) | When onboarding apps |

### Example Configurations

- **Minimal** (IT-only): See [terraform.tfvars.example](infra/terraform.tfvars.example)
- **Energy/Industrial** (full OT stack): See [energy-customer.tfvars](infra/energy-customer.tfvars)
- **Alert guidance**: See [docs/alert-recommendations.md](docs/alert-recommendations.md)

### Tear Down

```bash
terraform destroy -var-file=contoso.tfvars
az group delete --name rg-contoso-obs --yes
```

## Deployment Phases

| Phase | Scope | Duration |
|-------|-------|----------|
| **Phase 0** | Build accelerator assets (IaC, dashboards, playbook) — done once | Weeks 1-3 |
| **Phase 1** | Discovery & Assessment per customer | Weeks 1-4 |
| **Phase 2** | Foundation Deployment (agents, workspaces, pipelines) | Weeks 5-8 |
| **Phase 3** | Intelligence & Automation (AI alerts, predictive, ServiceNow) | Weeks 9-12 |
| **Phase 4** | Optimization & AI Enablement (tune, consolidate, ROI) | Weeks 13-16 |

See [docs/onboarding-playbook.md](docs/onboarding-playbook.md) for the full step-by-step guide.

## Key Metrics

| KPI | Target |
|-----|--------|
| MTTI reduction | ≥40% |
| MTTR reduction | ≥40% |
| Auto-remediated incidents | ≥30% |
| Monitoring coverage | 100% of resources |
| Alert noise reduction | ≥50% |

## Azure Services Used

| Component | Service | Role |
|-----------|---------|------|
| Hybrid projection | Azure Arc | Manage on-prem as Azure resources |
| Agent | Azure Monitor Agent (AMA) | Unified data collection via DCRs |
| Logs & Metrics | Log Analytics Workspace | Central query & storage engine |
| APM | Application Insights (workspace-based) | Distributed tracing, app performance |
| Instrumentation | OpenTelemetry + Azure Monitor Exporter | Vendor-neutral app telemetry |
| Security | Microsoft Sentinel | SIEM, SOAR, UEBA |
| OT/IoT | Azure IoT Hub + IoT Edge | Device management, edge compute |
| OT Security | Defender for IoT | Agentless OT network monitoring |
| OT Analytics | Microsoft Fabric (KQL DB + Lakehouse) | Real-time + historical OT analytics |
| Proactive Signals | Fabric Data Activator | Pattern-based triggers (no static alerts) |
| Predictive | Azure ML | MTTF prediction for IoT devices |
| Alerts | Azure Monitor Alert Rules | Dynamic thresholds, log-based, metric |
| Automation | Azure Automation Runbooks | L0/L1 self-healing |
| Orchestration | Logic Apps | ServiceNow ↔ Azure bidirectional workflows |
| ITSM | ServiceNow (ITSMC) | Incident mgmt, CMDB, change mgmt |
| IaC | Terraform | Repeatable deployment |
| Governance | Azure Policy | Enforce monitoring-by-default |
| Multi-tenant | Azure Lighthouse | Cross-customer management |
| Visualization | Azure Workbooks + Managed Grafana | Dashboards & reports |
| AI | Azure Copilot for Operations | NL queries over telemetry |
| Network | Network Watcher + NSG Flow Logs | Network observability |

## Team

| Person | Role |
|--------|------|
| Andrew Delosky | Lead / Account Strategy |
| Gaurav Bhardwaj | Emerging Tech / Accelerator Build |
| Wilkin Shum | Technical Contributor |
| Pat Lowe | ATU Industry SME |
| Yong/Hong | OT Observability (ATU) |
| Paul | Prior Observability POC |

## Weekly Cadence

Mondays 2:30 PM ET — recurring sync

## License

[MIT](LICENSE)
