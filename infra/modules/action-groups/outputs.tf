output "critical_action_group_id" {
  description = "Critical action group ID (for P1/P2 alerts)"
  value       = azurerm_monitor_action_group.critical.id
}

output "warning_action_group_id" {
  description = "Warning action group ID (for P3/P4 alerts)"
  value       = azurerm_monitor_action_group.warning.id
}

output "automation_action_group_id" {
  description = "Automation action group ID (for self-healing runbooks)"
  value       = azurerm_monitor_action_group.automation.id
}
