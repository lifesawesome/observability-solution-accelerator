# ============================================================================
# Network Observability Module
# Deploys Network Watcher, NSG Flow Logs, and Traffic Analytics
# ============================================================================

# Storage account for flow logs
resource "azurerm_storage_account" "flow_logs" {
  name                     = "stflowlogs${replace(var.customer_name, "-", "")}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags

  # Flow log data - lifecycle management
  blob_properties {
    delete_retention_policy {
      days = 30
    }
  }
}

# Network Watcher (one per region, may already exist)
resource "azurerm_network_watcher" "this" {
  name                = "nw-${var.customer_name}-${var.location}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# NSG Flow Logs — one per NSG provided
resource "azurerm_network_watcher_flow_log" "this" {
  for_each = var.nsg_ids

  name                      = "flowlog-${each.key}"
  network_watcher_name      = azurerm_network_watcher.this.name
  resource_group_name       = var.resource_group_name
  network_security_group_id = each.value
  storage_account_id        = azurerm_storage_account.flow_logs.id
  enabled                   = true
  version                   = 2
  tags                      = var.tags

  retention_policy {
    enabled = true
    days    = var.flow_log_retention_days
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = var.workspace_customer_id
    workspace_region      = var.location
    workspace_resource_id = var.workspace_id
    interval_in_minutes   = 10
  }
}
