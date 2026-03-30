output "ampls_id" {
  description = "Azure Monitor Private Link Scope resource ID"
  value       = azurerm_monitor_private_link_scope.this.id
}

output "private_endpoint_id" {
  description = "Private Endpoint resource ID for the AMPLS"
  value       = azurerm_private_endpoint.ampls.id
}

output "private_endpoint_ip" {
  description = "Private IP address assigned to the AMPLS private endpoint"
  value       = azurerm_private_endpoint.ampls.private_service_connection[0].private_ip_address
}

output "dns_zone_ids" {
  description = "Map of DNS zone purpose to zone ID (only when created by this module)"
  value       = { for k, v in azurerm_private_dns_zone.this : k => v.id }
}
