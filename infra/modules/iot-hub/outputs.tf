output "iot_hub_id" {
  description = "IoT Hub resource ID"
  value       = azurerm_iothub.this.id
}

output "hostname" {
  description = "IoT Hub hostname"
  value       = azurerm_iothub.this.hostname
}

output "eventhub_namespace_id" {
  description = "Event Hub Namespace ID for telemetry"
  value       = azurerm_eventhub_namespace.iot_telemetry.id
}

output "eventhub_connection_string" {
  description = "Event Hub connection string for Fabric/ADX consumers"
  value       = azurerm_eventhub_authorization_rule.fabric_listen.primary_connection_string
  sensitive   = true
}
