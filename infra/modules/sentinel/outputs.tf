output "sentinel_onboarding_id" {
  description = "Sentinel onboarding resource ID"
  value       = azurerm_sentinel_log_analytics_workspace_onboarding.this.id
}
