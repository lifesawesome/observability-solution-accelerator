output "network_watcher_id" {
  description = "Network Watcher resource ID"
  value       = azurerm_network_watcher.this.id
}

output "flow_logs_storage_id" {
  description = "Storage Account ID for flow logs"
  value       = azurerm_storage_account.flow_logs.id
}
