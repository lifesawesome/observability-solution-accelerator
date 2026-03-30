# ============================================================================
# Azure Monitor Private Link Scope (AMPLS) Module
# Provides private connectivity for Log Analytics, App Insights, and DCEs
# ============================================================================

resource "azurerm_monitor_private_link_scope" "this" {
  name                = var.ampls_name
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Controls whether resources scoped to this AMPLS accept public ingestion
  ingestion_access_mode = var.ingestion_access_mode
  query_access_mode     = var.query_access_mode
}

# --- Scope the Log Analytics Workspace into the AMPLS --------------------
resource "azurerm_monitor_private_link_scoped_service" "workspace" {
  name                = "scoped-workspace"
  resource_group_name = var.resource_group_name
  scope_name          = azurerm_monitor_private_link_scope.this.name
  linked_resource_id  = var.workspace_id
}

# --- Scope App Insights instances (if any) into the AMPLS ----------------
resource "azurerm_monitor_private_link_scoped_service" "app_insights" {
  for_each = var.app_insights_ids

  name                = "scoped-ai-${each.key}"
  resource_group_name = var.resource_group_name
  scope_name          = azurerm_monitor_private_link_scope.this.name
  linked_resource_id  = each.value
}

# --- Private Endpoint for the AMPLS (in customer's VNet) -----------------
resource "azurerm_private_endpoint" "ampls" {
  name                = "${var.ampls_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.ampls_name}-psc"
    private_connection_resource_id = azurerm_monitor_private_link_scope.this.id
    subresource_names              = ["azuremonitor"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = length(var.private_dns_zone_ids) > 0 ? [1] : []
    content {
      name                 = "ampls-dns-zones"
      private_dns_zone_ids = var.private_dns_zone_ids
    }
  }
}

# --- Private DNS Zones (optional, created only if not externally managed) -
locals {
  # All DNS zones required for Azure Monitor private link
  required_dns_zones = var.create_private_dns_zones ? {
    monitor         = "privatelink.monitor.azure.com"
    ods             = "privatelink.ods.opinsights.azure.com"
    oms             = "privatelink.oms.opinsights.azure.com"
    agentsvc        = "privatelink.agentsvc.azure-automation.net"
    blob            = "privatelink.blob.core.windows.net"
  } : {}
}

resource "azurerm_private_dns_zone" "this" {
  for_each = local.required_dns_zones

  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = local.required_dns_zones

  name                  = "${each.key}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.key].name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}
