# Workbooks Module

Deploys Azure Workbooks from local JSON definition files using the
`azurerm_application_insights_workbook` resource.

## Usage

```hcl
module "workbooks" {
  source = "./modules/workbooks"

  workbook_files = {
    "Network Overview" = "${path.root}/workbooks/network-overview.json"
    "AKS Health"       = "${path.root}/workbooks/aks-health.json"
  }

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  workspace_id        = azurerm_log_analytics_workspace.main.id
  tags                = local.tags
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `workbook_files` | `map(string)` | (required) | Map of workbook display name to the local file path of the JSON definition. |
| `resource_group_name` | `string` | (required) | Resource group for the workbook resources. |
| `location` | `string` | (required) | Azure region. |
| `workspace_id` | `string` | (required) | Log Analytics workspace resource ID used as the workbook source. |
| `tags` | `map(string)` | `{}` | Tags applied to every workbook resource. |

## Outputs

| Name | Description |
|------|-------------|
| `workbook_ids` | Map of workbook display name to Azure resource ID. |
| `workbook_count` | Total number of workbooks deployed. |
