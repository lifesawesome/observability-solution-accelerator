# ============================================================================
# Root Outputs
# ============================================================================

output "workspace_id" {
  description = "Log Analytics Workspace resource ID"
  value       = module.log_analytics.workspace_id
}

output "workspace_customer_id" {
  description = "Log Analytics Workspace customer ID (for agent config)"
  value       = module.log_analytics.workspace_customer_id
}

output "workspace_name" {
  description = "Log Analytics Workspace name"
  value       = module.log_analytics.workspace_name
}

output "app_insights_connection_strings" {
  description = "Application Insights connection strings per app"
  value       = { for k, v in module.app_insights : k => v.connection_string }
  sensitive   = true
}

output "dcr_windows_perf_id" {
  description = "Windows Performance DCR ID (for agent association)"
  value       = module.log_analytics.dcr_windows_perf_id
}

output "dcr_linux_perf_id" {
  description = "Linux Performance DCR ID (for agent association)"
  value       = module.log_analytics.dcr_linux_perf_id
}

output "action_group_critical_id" {
  description = "Critical action group ID"
  value       = module.action_groups.critical_action_group_id
}

output "iot_hub_hostname" {
  description = "IoT Hub hostname (if deployed)"
  value       = var.enable_iot_hub ? module.iot_hub[0].hostname : null
}
