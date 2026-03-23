output "enabled_services" {
  description = "List of Azure services with AMBA alerts deployed"
  value       = var.amba_services
}

output "alert_count" {
  description = "Total number of AMBA alert rules deployed"
  value = (
    (local.enable_vm ? 3 : 0) +
    (local.enable_sql ? 3 : 0) +
    (local.enable_appservice ? 3 : 0) +
    (local.enable_aks ? 3 : 0) +
    (local.enable_storage ? 2 : 0) +
    (local.enable_keyvault ? 2 : 0) +
    (local.enable_eventhub ? 1 : 0) +
    (local.enable_cosmosdb ? 2 : 0) +
    (local.enable_databricks ? 3 : 0) +
    (local.enable_loadbalancer ? 2 : 0)
  )
}
