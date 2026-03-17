output "app_insights_id" {
  description = "Application Insights resource ID"
  value       = azurerm_application_insights.this.id
}

output "connection_string" {
  description = "Application Insights connection string (use for OTel SDK)"
  value       = azurerm_application_insights.this.connection_string
  sensitive   = true
}

output "instrumentation_key" {
  description = "Application Insights instrumentation key (legacy)"
  value       = azurerm_application_insights.this.instrumentation_key
  sensitive   = true
}

output "app_id" {
  description = "Application Insights application ID"
  value       = azurerm_application_insights.this.app_id
}
