output "workbook_ids" {
  description = "Map of workbook display name to the Azure resource ID."
  value = {
    for name, wb in azurerm_application_insights_workbook.workbook :
    name => wb.id
  }
}

output "workbook_count" {
  description = "Number of workbooks deployed."
  value       = length(azurerm_application_insights_workbook.workbook)
}
