output "diagnostic_setting_ids" {
  description = "Map of resource name to diagnostic setting ID"
  value       = { for k, v in azurerm_monitor_diagnostic_setting.this : k => v.id }
}

output "diagnostic_count" {
  description = "Number of diagnostic settings deployed"
  value       = length(azurerm_monitor_diagnostic_setting.this)
}
