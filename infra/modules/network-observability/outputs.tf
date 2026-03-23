output "network_watcher_id" {
  description = "Network Watcher resource ID"
  value       = azurerm_network_watcher.this.id
}

output "flow_logs_storage_id" {
  description = "Storage Account ID for flow logs"
  value       = azurerm_storage_account.flow_logs.id
}

output "flow_log_ids" {
  description = "Map of NSG name to flow log resource ID"
  value       = { for k, v in azurerm_network_watcher_flow_log.this : k => v.id }
}
