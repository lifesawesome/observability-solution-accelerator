# ============================================================================
# Action Groups Module
# Defines notification channels: email, ServiceNow webhook, Teams
# ============================================================================

# --- Critical Action Group (P1/P2 alerts) ---
resource "azurerm_monitor_action_group" "critical" {
  name                = "ag-${var.customer_name}-critical"
  resource_group_name = var.resource_group_name
  short_name          = "Critical"
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = var.email_recipients
    content {
      name          = "email-${email_receiver.key}"
      email_address = email_receiver.value
    }
  }

  dynamic "webhook_receiver" {
    for_each = var.servicenow_webhook_uri != "" ? [1] : []
    content {
      name                    = "servicenow-incident"
      service_uri             = var.servicenow_webhook_uri
      use_common_alert_schema = true
    }
  }
}

# --- Warning Action Group (P3/P4 alerts) ---
resource "azurerm_monitor_action_group" "warning" {
  name                = "ag-${var.customer_name}-warning"
  resource_group_name = var.resource_group_name
  short_name          = "Warning"
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = var.email_recipients
    content {
      name          = "email-${email_receiver.key}"
      email_address = email_receiver.value
    }
  }
}

# --- Automation Action Group (L0 self-healing) ---
resource "azurerm_monitor_action_group" "automation" {
  name                = "ag-${var.customer_name}-automation"
  resource_group_name = var.resource_group_name
  short_name          = "AutoHeal"
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = var.email_recipients
    content {
      name          = "email-${email_receiver.key}"
      email_address = email_receiver.value
    }
  }
}
