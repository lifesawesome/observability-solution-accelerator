# Customer Onboarding Guide

Welcome! This guide will get your Azure environment fully monitored in **under 30 minutes**.

---

## What You'll Get

Once onboarded, your subscription will have:

- **Automatic resource discovery** — every VM, database, app service, container, and IoT device found and cataloged
- **Log collection** — all resources sending logs to a central Log Analytics workspace
- **Pre-built dashboards** — tailored to your actual resources:

| If You Have... | You Get This Dashboard |
|---------------|----------------------|
| Virtual Machines | VM Logs — CPU, memory, disk, heartbeat, event logs |
| App Services / Functions | Application Logs — errors, latency, dependencies, traces |
| AKS Clusters | Kubernetes Logs — pods, containers, nodes, cluster events |
| IoT Hubs | IoT Logs — device health, message throughput, routing |
| NSGs / VNets | Network Logs — flow analytics, connectivity, bandwidth |

- **Alerts** — pre-configured for critical issues (disk full, VM down, app errors, etc.)
- **Microsoft Sentinel** — security monitoring enabled by default
- **Azure Policy** — auto-enrolls new resources into monitoring

---

## Prerequisites

You need **3 things** before starting:

| # | Requirement | How to Get It |
|---|------------|---------------|
| 1 | **Azure Subscription ID** | Run: `az account show --query id -o tsv` |
| 2 | **Resource Group** | Create one: `az group create --name rg-yourcompany-obs --location westus2` |
| 3 | **Contributor + User Access Administrator** role on the subscription | Ask your Azure admin to assign these roles to your account |

### Software (install once)

```bash
# Azure CLI
# https://learn.microsoft.com/en-us/cli/azure/install-azure-cli

# Python 3.9+
# https://www.python.org/downloads/

# Terraform 1.5+
# https://developer.hashicorp.com/terraform/install
```

---

## Step 1: Clone the Accelerator

```bash
git clone <repo-url>
cd observability-solution-accelerator
```

## Step 2: Install Dependencies

```bash
pip install -r discovery/requirements.txt
```

## Step 3: Log In to Azure

```bash
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

## Step 4: Run the Accelerator

Replace the 3 values below with yours:

```bash
python accelerator.py \
  --subscription-id "YOUR_SUBSCRIPTION_ID" \
  --customer-name "yourcompany" \
  --resource-group "rg-yourcompany-obs" \
  --location "westus2"
```

> **customer-name** must be lowercase letters, numbers, and hyphens only (e.g., `contoso`, `fabrikam-prod`).

That's it. The accelerator will:

1. Scan your subscription and find all resources
2. Generate dashboards matched to your environment
3. Show you a Terraform plan of what will be deployed
4. Wait for your approval before deploying

### Want to skip the approval prompt?

```bash
python accelerator.py \
  --subscription-id "YOUR_SUBSCRIPTION_ID" \
  --customer-name "yourcompany" \
  --resource-group "rg-yourcompany-obs" \
  --auto-approve
```

### Just want to preview without deploying?

```bash
python accelerator.py \
  --subscription-id "YOUR_SUBSCRIPTION_ID" \
  --customer-name "yourcompany" \
  --resource-group "rg-yourcompany-obs" \
  --dry-run
```

---

## Step 5: Verify Your Deployment

After deployment completes, verify in the Azure Portal:

1. **Log Analytics Workspace** — Go to your resource group → find `la-yourcompany-obs` → confirm it exists
2. **Workbooks** — In the workspace, click **Workbooks** in the left menu → your dashboards should appear
3. **Alerts** — Go to **Monitor → Alerts** → confirm alert rules are active
4. **Policy** — Go to **Policy → Assignments** → confirm AMA and DCR policies are assigned

Or run the smoke test:

```bash
./tests/smoke-test.sh rg-yourcompany-obs yourcompany --sentinel
```

---

## What Gets Deployed

| Resource | Description |
|----------|-------------|
| Log Analytics Workspace | Central log storage (90-day retention) |
| Data Collection Rules | Auto-collect Windows + Linux performance data |
| Microsoft Sentinel | Security monitoring (SIEM) |
| Alert Rules | Heartbeat loss, CPU anomaly, disk space, memory, app exceptions |
| Action Groups | Email + webhook notification channels |
| Azure Policy | Auto-deploy monitoring agent to all VMs |
| Network Watcher | Network flow log collection |
| Azure Workbooks | 1-5 dashboards based on your resources |

---

## Optional: Enable Extra Features

Add these flags to your command to enable additional modules:

```bash
python accelerator.py \
  --subscription-id "YOUR_SUBSCRIPTION_ID" \
  --customer-name "yourcompany" \
  --resource-group "rg-yourcompany-obs"
```

Then edit the generated `.tfvars` file (`infra/yourcompany.auto.tfvars`) to customize:

| Setting | Default | Change To | When |
|---------|---------|-----------|------|
| `enable_sentinel` | `true` | `false` | You already have Sentinel elsewhere |
| `enable_iot_hub` | auto-detected | `true` | Force-enable IoT Hub monitoring |
| `enable_aks` | auto-detected | `true` | Force-enable AKS monitoring |
| `enable_amba` | auto-detected | `true` | Enable service-specific alert packs |
| `workspace_retention_days` | `90` | `365` | Compliance requirement for longer retention |
| `alert_email_recipients` | `[]` | `["noc@company.com"]` | Get alert emails |

After editing, deploy the changes:

```bash
cd infra
terraform apply -var-file=yourcompany.auto.tfvars
```

---

## Optional: Instrument Your Applications

To get **application-level** monitoring (traces, errors, request metrics), add OpenTelemetry to your apps:

| Language | Guide |
|----------|-------|
| .NET | [docs/instrumentation/dotnet.md](docs/instrumentation/dotnet.md) |
| Java | [docs/instrumentation/java.md](docs/instrumentation/java.md) |
| Node.js | [docs/instrumentation/nodejs.md](docs/instrumentation/nodejs.md) |
| Python | [docs/instrumentation/python.md](docs/instrumentation/python.md) |

Your Application Insights connection string is in the Terraform output:

```bash
cd infra
terraform output app_insights_connection_strings
```

---

## Tear Down

To remove everything:

```bash
cd infra
terraform destroy -var-file=yourcompany.auto.tfvars
az group delete --name rg-yourcompany-obs --yes
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `az login` fails | Make sure Azure CLI is installed and updated: `az upgrade` |
| Discovery finds 0 resources | Check you're authenticated to the right subscription: `az account show` |
| Terraform init fails | Make sure Terraform >= 1.5.0 is installed: `terraform version` |
| Permission denied during deploy | You need **Contributor** + **User Access Administrator** on the subscription |
| Workbooks are empty | Wait 15-30 minutes for logs to start flowing into the workspace |
| No alerts firing | Alerts need data. Check that VMs have the monitoring agent installed (Policy may take ~30 min to auto-deploy) |

---

## Support

| Contact | Role |
|---------|------|
| Gaurav Bhardwaj | Accelerator technical lead |
| Andrew Delosky | Account strategy |

---

*Last updated: March 2026*
