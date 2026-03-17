output "workspace_id" {
  description = "Log Analytics Workspace resource ID"
  value       = azurerm_log_analytics_workspace.this.id
}

output "workspace_name" {
  description = "Log Analytics Workspace name"
  value       = azurerm_log_analytics_workspace.this.name
}

output "workspace_customer_id" {
  description = "Log Analytics Workspace customer ID"
  value       = azurerm_log_analytics_workspace.this.workspace_id
}

output "primary_shared_key" {
  description = "Primary shared key for agent configuration"
  value       = azurerm_log_analytics_workspace.this.primary_shared_key
  sensitive   = true
}

output "dcr_windows_perf_id" {
  description = "Windows Performance DCR resource ID"
  value       = azurerm_monitor_data_collection_rule.windows_perf.id
}

output "dcr_linux_perf_id" {
  description = "Linux Performance DCR resource ID"
  value       = azurerm_monitor_data_collection_rule.linux_perf.id
}
