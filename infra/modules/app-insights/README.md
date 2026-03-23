# Application Insights Module

Deploys workspace-based Application Insights for OpenTelemetry-instrumented applications.

## Usage

```hcl
module "app_insights" {
  source = "./modules/app-insights"

  resource_group_name = "rg-customer-obs"
  location            = "westus2"
  app_insights_name   = "ai-customer-webapp"
  workspace_id        = module.log_analytics.workspace_id
  tags                = { app = "webapp" }
}
```

## Outputs

| Name | Description |
|------|-------------|
| `connection_string` | Use in OTel SDK configuration (sensitive) |
| `instrumentation_key` | Legacy key (prefer connection string) |
