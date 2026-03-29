resource "azurerm_application_insights_workbook" "workbook" {
  for_each = var.workbook_files

  name                = uuidv5("dns", "${each.key}-${var.workspace_id}")
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = each.key
  data_json           = file(each.value)
  source_id           = var.workspace_id
  tags                = var.tags
}
