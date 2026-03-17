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
