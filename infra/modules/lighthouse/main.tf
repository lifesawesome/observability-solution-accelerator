# ============================================================================
# Azure Lighthouse Module
# Configures cross-tenant delegation from customer to hub MSP tenant
# ============================================================================

resource "azurerm_lighthouse_definition" "observability" {
  name               = "${var.customer_name}-observability-delegation"
  description        = "Observability Accelerator - delegated access for ${var.customer_name}"
  managing_tenant_id = var.hub_tenant_id

  scope = "/subscriptions/${data.azurerm_subscription.current.subscription_id}"

  # Monitoring Reader - read metrics, logs, alerts
  authorization {
    principal_id           = var.hub_principal_id
    role_definition_name   = "Monitoring Reader"
    principal_display_name = "Observability Hub - Monitoring Reader"
  }

  # Log Analytics Reader - query logs cross-tenant
  authorization {
    principal_id           = var.hub_principal_id
    role_definition_name   = "Log Analytics Reader"
    principal_display_name = "Observability Hub - Log Analytics Reader"
  }

  # Sentinel Reader - view security incidents
  authorization {
    principal_id           = var.hub_principal_id
    role_definition_name   = "Microsoft Sentinel Reader"
    principal_display_name = "Observability Hub - Sentinel Reader"
  }
}

resource "azurerm_lighthouse_assignment" "observability" {
  scope                    = "/subscriptions/${data.azurerm_subscription.current.subscription_id}"
  lighthouse_definition_id = azurerm_lighthouse_definition.observability.id
}

data "azurerm_subscription" "current" {}
