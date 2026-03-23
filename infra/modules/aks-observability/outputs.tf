output "dcr_id" {
  description = "Container Insights Data Collection Rule ID"
  value       = azurerm_monitor_data_collection_rule.aks_ci.id
}

output "diagnostic_setting_id" {
  description = "AKS diagnostic setting ID"
  value       = azurerm_monitor_diagnostic_setting.aks.id
}
