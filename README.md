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
| `accelerator.py` | **One-command CLI** — discover, provision, generate, deploy |
| `discovery/` | Resource scanner (`scan_subscription.py`), workbook generator (`generate_workbooks.py`), deployer (`deploy_workbooks.py`) |
| `infra/` | Terraform root config (`main.tf`, `variables.tf`, `outputs.tf`, `providers.tf`) |
| `infra/modules/` | Terraform modules: log-analytics-spoke, sentinel, app-insights, alert-rules, action-groups, amba-alerts, aks-observability, iot-hub, lighthouse, network-observability, workbooks, policy-initiative, diagnostic-settings, ampls, fabric-workspace |
| `dashboards/workbooks/` | 15 pre-built Azure Workbook JSON templates (VM, K8s, IoT, App, Network, Storage, Key Vault, SQL, Cosmos DB, Logic App, infra health, cost, security, performance, MTTI/MTTR) |
| `dashboards/powerbi/` | Power BI templates for OT observability |
| `automation/runbooks/` | Azure Automation runbooks for L0 remediation |
| `automation/logic-apps/` | Logic App templates for ServiceNow integration |
| `policies/` | Azure Policy definitions and initiatives |
| `docs/` | Architecture docs, onboarding playbook, instrumentation guides |
| `templates/` | Assessment templates (gap analysis, partner matrix) |
| `generated-workbooks/` | *(auto-created)* Customer-specific workbooks from discovery |

## Quick Start — One-Command Accelerator (NEW)

The fastest way to deploy. The accelerator **auto-discovers** your Azure resources, **generates dashboards**, and **deploys everything** with a single command.

### Prerequisites

| Requirement | Details |
|------------|---------|
| **Python** | >= 3.10 with pip |
| **Azure CLI** | Latest version, authenticated (`az login`) |
| **Azure Subscription** | With **Contributor** + **User Access Administrator** roles |
| **Terraform** | >= 1.5.0 — *only needed for full deploy mode, not discovery-only* |

### One-Command Deploy

```bash
git clone <repo-url>
cd observability-solution-accelerator

# Install Python dependencies
pip install -r discovery/requirements.txt

# Run the accelerator — discovers resources, creates RG & workspace, generates and deploys workbooks
python accelerator.py \
  --subscription-id "your-subscription-id" \
  --customer-name "contoso" \
  --location "westus2" \
  --discovery-only
```

> **No pre-created resources needed.** The accelerator auto-creates the resource group (`rg-contoso-obs`) and Log Analytics workspace (`la-contoso-obs`) for you.

This single command will:
1. **Scan** your subscription and inventory all resources (VMs, AKS, IoT, App Services, databases, networking, etc.)
2. **Detect network posture** — identifies publicly accessible resources and private endpoint coverage
3. **Auto-create** the resource group and Log Analytics workspace
4. **Generate** type-specific Azure Workbooks based on discovered resources
5. **Deploy** all generated workbooks to your workspace automatically

Add `--resource-group "my-custom-rg"` to override the default resource group name.

### Full Deploy (Terraform)

For the complete stack (Sentinel, alerts, policies, automation), use full deploy mode:

```bash
python accelerator.py \
  --subscription-id "your-subscription-id" \
  --customer-name "contoso" \
  --resource-group "rg-contoso-obs" \
  --location "westus2"
```

This runs discovery, generates a `.tfvars` file, and executes `terraform plan`. Add `--auto-approve` to deploy without review, or `--dry-run` to preview all steps.

### What Gets Auto-Generated

| Discovered Resources | Auto-Generated Workbook | Terraform Feature |
|---------------------|------------------------|-------------------|
| VMs, VMSS | VM Logs (CPU, memory, disk, events) | `enable_amba = true` |
| AKS Clusters | K8s Logs (pods, containers, nodes) | `enable_aks = true` |
| IoT Hubs | IoT Logs (device health, telemetry) | `enable_iot_hub = true` |
| App Services, Functions | Application Logs (errors, latency, traces) | App Insights apps detected |
| NSGs, VNets, Load Balancers | Network Logs (flows, connectivity) | `enable_network_observability = true` |
| Storage Accounts | Storage Logs (blob/queue/table operations, latency) | Diagnostic settings |
| Key Vaults | Key Vault Logs (access, secrets, certificates) | Diagnostic settings |
| SQL Databases | SQL Logs (DTU, connections, deadlocks) | Diagnostic settings |
| Cosmos DB Accounts | Cosmos DB Logs (RU consumption, latency, errors) | Diagnostic settings |
| Logic Apps | Logic App Logs (run history, failures, latency) | Diagnostic settings |
| *(all resources)* | Infrastructure Health (cross-resource health overview) | — |
| *(all resources)* | Cost & Usage (resource costs, trends) | — |
| *(all resources)* | App Performance (request rate, response time, failures) | — |
| *(Sentinel enabled)* | Security Posture (incidents, alerts, compliance) | `enable_sentinel = true` |

### Multi-Subscription Scanning

Scan multiple subscriptions in a single run, or auto-discover all subscriptions in your tenant:

```bash
# Scan specific subscriptions
python accelerator.py \
  --subscription-ids "sub-id-1,sub-id-2,sub-id-3" \
  --customer-name "contoso" \
  --discovery-only

# Auto-discover and scan all subscriptions in the tenant
python accelerator.py \
  --tenant-scan \
  --customer-name "contoso" \
  --discovery-only
```

Multi-subscription mode merges all discovered resources into a single inventory and generates one unified set of workbooks.

### Network Posture Detection

The discovery scan automatically checks every resource for:

- **Public network access** — flags resources with `publicNetworkAccess` enabled
- **Private endpoint coverage** — detects whether private endpoints are configured

The output includes a `network_posture` section per subscription with counts of public-facing vs. private resources. Use this to prioritize security hardening before or alongside the observability rollout.

---

## Manual Deployment Guide

> **Recommended**: Run `--discovery-only` mode first to get instant workbooks and visibility before committing to a full Terraform deployment.

If you prefer full control, you can manually create a `.tfvars` file and deploy step by step.

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
| Azure Workbooks | up to 11 | **Auto-generated and deployed** from discovery (VM, Network, App, K8s, IoT, Storage, Key Vault, SQL, Cosmos DB, Logic App, infra health, cost, security, performance) |

### Post-Deploy Steps (Optional)

| Task | How | When |
|------|-----|------|
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

## Customer Onboarding Process

Step-by-step process to onboard a new customer onto the observability platform.

### Step 1: Discovery (Day 1)

Run the accelerator in discovery-only mode to scan the customer's environment and deploy instant dashboards:

```bash
# Single subscription
python accelerator.py \
  --subscription-id "customer-sub-id" \
  --customer-name "acme" \
  --discovery-only

# Or scan all subscriptions in their tenant
python accelerator.py \
  --tenant-scan \
  --customer-name "acme" \
  --discovery-only
```

**Output**: Resource inventory JSON (`discovery-output.json`), network posture report, up to 11 workbooks auto-deployed.

### Step 2: Review Discovery Results

1. Open the generated workbooks in Azure Portal → Monitor → Workbooks
2. Review network posture — prioritize resources with public access enabled
3. Check `discovery-output.json` for resource categories found and feature flags detected
4. Share the workbook screenshots with the customer as immediate value

### Step 3: Full Foundation Deploy (Week 1-2)

Once the customer approves, deploy the full stack:

```bash
python accelerator.py \
  --subscription-id "customer-sub-id" \
  --customer-name "acme" \
  --resource-group "rg-acme-obs" \
  --location "westus2" \
  --auto-approve
```

This adds: Sentinel, alert rules, action groups, policies (AMA auto-enrollment), data collection rules, and network observability.

### Step 4: Configure Integrations (Week 2-3)

| Integration | How |
|-------------|-----|
| ServiceNow ITSM | Deploy Logic Apps from `automation/logic-apps/` → configure webhook URI |
| Auto-Remediation | Import runbooks from `automation/runbooks/` → link to action groups |
| Application Monitoring | Instrument apps using guides in `docs/instrumentation/` |
| Lighthouse (if MSP) | Enable with `enable_lighthouse = true` for cross-tenant management |

### Step 5: Validate and Tune (Week 3-4)

1. Run the smoke test: `./tests/smoke-test.sh rg-acme-obs acme --sentinel`
2. Inject test data: `python tests/inject-fake-data.py`
3. Review alert noise and tune thresholds in `.tfvars`
4. Review MTTI/MTTR workbook for baseline metrics

See [docs/onboarding-playbook.md](docs/onboarding-playbook.md) and [docs/customer-onboarding.md](docs/customer-onboarding.md) for detailed guidance.

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
