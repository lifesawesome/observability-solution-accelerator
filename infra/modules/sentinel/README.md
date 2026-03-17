# Microsoft Sentinel Module

Enables Microsoft Sentinel on an existing Log Analytics workspace with pre-built analytics rules.

## What It Deploys
- Sentinel onboarding on the workspace
- Brute force attack detection rule
- Anomalous Azure activity detection rule

## Usage

```hcl
module "sentinel" {
  source = "./modules/sentinel"

  resource_group_name        = "rg-customer-obs"
  workspace_name             = "la-customer-obs"
  workspace_id               = module.log_analytics.workspace_id
  log_analytics_workspace_id = module.log_analytics.workspace_id
}
```
