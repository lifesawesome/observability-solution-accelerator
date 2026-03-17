# Customer Onboarding Playbook

Step-by-step guide for deploying the Observability Solution Accelerator to a new customer.

---

## Phase 0: Accelerator Build (Done Once)

**Owner**: Gaurav Bhardwaj  
**Duration**: Weeks 1-3 (one-time investment)

### Deliverables

- [x] Terraform modules for all Azure components
- [x] Azure Workbook templates (MTTI/MTTR, infra health, app performance, security, cost)
- [x] Azure Policy initiative ("Monitor Everything")
- [x] Sentinel analytics rule templates
- [x] Alert rule library (CPU, memory, disk, heartbeat, app error rate)
- [x] OpenTelemetry instrumentation guides (.NET, Java, Node.js, Python)
- [x] Gap analysis & partner tool matrix templates
- [ ] Power BI OT dashboard template
- [ ] Logic App templates for ServiceNow bidirectional sync
- [ ] Azure Automation L0 runbooks (restart service, clear disk, restart VM)

---

## Phase 1: Discovery & Assessment (Per Customer)

**Owner**: Lead + Technical Contributor  
**Duration**: Weeks 1-4

### 1.1 Kickoff & Inventory

| Step | Action | Tool |
|------|--------|------|
| 1 | Schedule kickoff with customer IT/OT teams | Teams |
| 2 | Run Azure Resource Graph inventory query | `az graph query` |
| 3 | Enumerate on-prem servers (Arc candidates) | Customer CMDB or manual |
| 4 | Identify OT/IoT device fleet and protocols | Site survey |
| 5 | Collect existing monitoring tool list | Interview |

### 1.2 Gap Analysis

Use the [Gap Analysis Template](../templates/gap-analysis-template.md) to score each pillar:

| Pillar | Assessment Areas |
|--------|-----------------|
| IT Infrastructure | Agent coverage, alert quality, dashboard maturity |
| Application | APM adoption, distributed tracing, error tracking |
| Security | SIEM presence, incident response SLA, UEBA |
| OT/IoT | Device management, edge compute, OT security |
| Automation | Incident workflow, auto-remediation, CMDB accuracy |

### 1.3 Tool Rationalization

Use the [Partner Tool Matrix](../templates/partner-tool-matrix.md) to map existing tools to Azure equivalents and identify consolidation opportunities.

### 1.4 Design Document

Produce a customer-specific design document covering:
- Hub-spoke workspace topology decisions
- Data retention and commitment tier sizing
- Sentinel data connector selection
- IoT Hub SKU and device provisioning plan
- ServiceNow integration scope (CMDB → incidents → changes)

---

## Phase 2: Foundation Deployment (Per Customer)

**Owner**: Technical implementation team  
**Duration**: Weeks 5-8

### 2.1 Prerequisites

```bash
# Ensure Terraform is installed
terraform --version  # >= 1.5.0

# Login to customer Azure subscription
az login --tenant <customer-tenant-id>
az account set --subscription <customer-subscription-id>

# Create resource group
az group create --name rg-<customer>-observability --location eastus2
```

### 2.2 Deploy Core Infrastructure

```bash
cd infra/

# Copy and customize the tfvars file
cp terraform.tfvars.example customer.tfvars
# Edit customer.tfvars with customer-specific values

# Initialize and deploy
terraform init
terraform plan -var-file=customer.tfvars -out=plan.tfplan
terraform apply plan.tfplan
```

### 2.3 Deploy Azure Monitor Agent via Policy

The `policy-initiative` module assigns policies that auto-deploy AMA. After `terraform apply`:

1. Go to Azure Portal → Policy → Compliance
2. Verify the "Monitor Everything" initiative assignments are compliant
3. Trigger a remediation task for existing VMs that don't have AMA yet:

```bash
az policy remediation create \
  --name "deploy-ama-windows" \
  --policy-assignment "<assignment-id>" \
  --resource-group "rg-<customer>-observability"
```

### 2.4 Onboard Hybrid Servers via Azure Arc

```bash
# Generate Arc onboarding script
az connectedmachine generate-script \
  --resource-group rg-<customer>-observability \
  --location eastus2 \
  --subscription-id <sub-id>

# Run the generated script on each on-prem server
# (or distribute via GPO / Ansible / SCCM)
```

### 2.5 Configure Application Insights

For each application, follow the appropriate instrumentation guide:
- [.NET](instrumentation/dotnet.md)
- [Java](instrumentation/java.md)
- [Node.js](instrumentation/nodejs.md)
- [Python](instrumentation/python.md)

### 2.6 Set Up Sentinel Data Connectors

In Azure Portal → Sentinel → Data Connectors, enable:
- Azure Activity
- Azure AD Sign-in Logs
- Microsoft 365 Defender
- Microsoft Defender for Cloud
- Azure Firewall (if applicable)
- Syslog / CEF (for on-prem firewalls via Arc)

### 2.7 IoT Hub & Fabric (if OT scope)

1. Register IoT Edge devices with the IoT Hub created by Terraform
2. Deploy OPC-UA / Modbus modules to IoT Edge
3. Verify telemetry flows to Event Hub
4. In Fabric portal: create Eventhouse → Get Data → Event Hub
5. Create Lakehouse with shortcut from KQL Database
6. Configure Data Activator reflexes for proactive triggers

---

## Phase 3: Intelligence & Automation

**Owner**: Technical implementation + customer ops team  
**Duration**: Weeks 9-12

### 3.1 Tune Alert Rules

1. Run alerts in observation mode for 2 weeks
2. Review alert noise — suppress false positives
3. Adjust dynamic threshold sensitivity per resource type
4. Add customer-specific KQL alert rules as needed

### 3.2 Enable ServiceNow Integration

```text
ServiceNow  ◄────────────────►  Logic App
   ├── Incident auto-create       (Action Group webhook triggers Logic App)
   ├── Incident update sync        (bi-directional via REST API)
   └── CMDB sync                   (Resource Graph → CMDB import)
```

Steps:
1. Create ServiceNow ITSM tables (if greenfield)
2. Deploy Logic App template for incident creation
3. Configure Action Group webhook → Logic App HTTP trigger
4. Test end-to-end: alert fires → ServiceNow incident created
5. Set up CMDB bootstrap: Azure Resource Graph → ServiceNow CMDB

### 3.3 Deploy L0 Automation Runbooks

| Runbook | Trigger | Action |
|---------|---------|--------|
| Restart Windows Service | Service stopped alert | `Restart-Service` via Run Command |
| Clear Temp Files | Disk > 90% alert | Delete temp/log files |
| Restart VM | Heartbeat lost > 15 min | `Restart-AzVM` |
| Scale Up | CPU > 95% for 30 min | Resize VM SKU |

### 3.4 Enable Predictive Intelligence

- Enable Sentinel UEBA
- Deploy KQL anomaly detection rules (`series_decompose_anomalies`)
- Set up Azure ML workspace for MTTF prediction (Phase 4 refinement)

---

## Phase 4: Optimization & AI Enablement

**Owner**: Full team + customer executives  
**Duration**: Weeks 13-16

### 4.1 Alert Noise Reduction

```kusto
// Find noisy alert rules (>50 fires in 30 days)
AlertsManagementResources
| where type == 'microsoft.alertsmanagement/alerts'
| where properties.essentials.startDateTime > ago(30d)
| summarize Count = count() by RuleName = tostring(properties.essentials.alertRule)
| where Count > 50
| order by Count desc
```

### 4.2 Cost Optimization

- Review workspace commitment tier fit (see cost-usage workbook)
- Move low-value tables to Basic Logs tier
- Set appropriate retention per table (default 90d, security 365d)
- Configure sampling for high-traffic Application Insights

### 4.3 Build ROI Report

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| MTTI (avg, minutes) | ___ | ___ | ___% |
| MTTR (avg, minutes) | ___ | ___ | ___% |
| Auto-remediated incidents | 0% | ___% | — |
| Monitoring coverage | ___% | 100% | — |
| Alert noise (false positives) | ___ | ___ | ___% reduction |
| Monthly monitoring cost | $___ | $___ | — |

### 4.4 Knowledge Transfer

- Walk customer ops team through all workbooks
- Train on KQL basics for ad-hoc investigation
- Document customer-specific runbook procedures
- Hand off Terraform state and pipeline ownership (if customer-managed)

---

## Repeatable Cadence

After initial deployment, maintain with weekly sync (Mondays 2:30 PM ET):

| Week | Focus |
|------|-------|
| 1-2 | Alert noise review, tune thresholds |
| 3-4 | ServiceNow workflow refinement |
| Monthly | MTTI/MTTR trend review, cost review |
| Quarterly | ROI report, roadmap planning |
