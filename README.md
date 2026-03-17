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

## Quick Start

Deploy a full customer observability stack:

```bash
# Login to Azure
az login

# Create a resource group for the customer
az group create --name rg-customer-obs --location eastus2

# Deploy the full stack with Terraform
cd infra/
cp terraform.tfvars.example customer.tfvars
# Edit customer.tfvars with customer-specific values

terraform init
terraform plan -var-file=customer.tfvars -out=plan.tfplan
terraform apply plan.tfplan
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
