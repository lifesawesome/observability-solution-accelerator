# ============================================================================
# Diagnostic Settings Module
# Enables diagnostic log collection from discovered resources to Log Analytics
# Supports resources with publicNetworkAccess=Disabled via trusted service bypass
# ============================================================================

# --- Diagnostic settings for each resource passed in --------------------
resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = var.resource_ids

  name                       = "diag-${var.customer_name}-obs"
  target_resource_id         = each.value
  log_analytics_workspace_id = var.workspace_id

  # Enable all available log categories dynamically
  dynamic "enabled_log" {
    for_each = var.log_categories_per_resource[each.key]
    content {
      category = enabled_log.value
    }
  }

  # Enable metrics for all resources
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
