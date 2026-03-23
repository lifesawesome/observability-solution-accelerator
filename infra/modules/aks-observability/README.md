# AKS Observability Module

Enables comprehensive Kubernetes monitoring for AKS clusters including Container Insights, diagnostic settings, and recommended alert rules.

## What Gets Deployed

| Resource | Purpose |
|----------|---------|
| Diagnostic Setting | Streams kube-apiserver, kube-controller-manager, kube-scheduler, kube-audit-admin, guard logs + AllMetrics to Log Analytics |
| Data Collection Rule | Container Insights v2 with 1-minute collection interval |
| DCR Association | Links the DCR to the AKS cluster |
| 5 Alert Rules | OOMKilled, PV usage, Node NotReady, Pods stuck Pending, Excessive restarts |

## Alert Rules

| Alert | Severity | Description |
|-------|----------|-------------|
| OOMKilled Containers | Sev 1 | Containers terminated due to memory exhaustion |
| PV Usage > 85% | Sev 2 | Persistent volume disk nearing capacity |
| Node Not Ready | Sev 1 | Cluster nodes in NotReady state |
| Pods Stuck Pending | Sev 2 | Pods unable to schedule for > 10 minutes |
| Excessive Restarts | Sev 2 | Containers restarting > 5 times in 30 minutes |

## Usage

```hcl
module "aks_observability" {
  source = "./modules/aks-observability"

  resource_group_name = "rg-customer-obs"
  location            = "westus2"
  aks_cluster_id      = "/subscriptions/.../resourceGroups/.../providers/Microsoft.ContainerService/managedClusters/my-cluster"
  workspace_id        = module.log_analytics.workspace_id
  action_group_id     = module.action_groups.critical_action_group_id
  customer_name       = "marathon"
}
```

## Prerequisites

- AKS cluster must exist and be accessible
- Log Analytics workspace must be provisioned
- Action group must be created
