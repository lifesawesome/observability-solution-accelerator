# ============================================================================
# Azure Policy Initiative Module - "Monitor Everything"
# Assigns policies to auto-deploy AMA and enable diagnostics
# ============================================================================

# --- Policy: Deploy AMA extension on Windows VMs ---
resource "azurerm_subscription_policy_assignment" "ama_windows" {
  name                 = "${var.customer_name}-deploy-ama-windows"
  display_name         = "[${var.customer_name}] Deploy AMA on Windows VMs"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/ca817e41-e85a-4783-bc7f-dc532d36235e"
  enforcement_mode     = true
  location             = "eastus2"

  identity {
    type = "SystemAssigned"
  }
}

# --- Policy: Deploy AMA extension on Linux VMs ---
resource "azurerm_subscription_policy_assignment" "ama_linux" {
  name                 = "${var.customer_name}-deploy-ama-linux"
  display_name         = "[${var.customer_name}] Deploy AMA on Linux VMs"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/a4034bc6-ae50-406d-bf76-50f4ee5a7571"
  enforcement_mode     = true
  location             = "eastus2"

  identity {
    type = "SystemAssigned"
  }
}

# --- Policy: Deploy AMA on Arc-enabled Windows servers ---
resource "azurerm_subscription_policy_assignment" "ama_arc_windows" {
  name                 = "${var.customer_name}-deploy-ama-arc-win"
  display_name         = "[${var.customer_name}] Deploy AMA on Arc Windows Servers"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/94f686d6-9a24-4e19-91f1-de937bc89f66"
  enforcement_mode     = true
  location             = "eastus2"

  identity {
    type = "SystemAssigned"
  }
}

# --- Policy: Deploy AMA on Arc-enabled Linux servers ---
resource "azurerm_subscription_policy_assignment" "ama_arc_linux" {
  name                 = "${var.customer_name}-deploy-ama-arc-lnx"
  display_name         = "[${var.customer_name}] Deploy AMA on Arc Linux Servers"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/845857af-0333-4c5d-bbbc-6076697da122"
  enforcement_mode     = true
  location             = "eastus2"

  identity {
    type = "SystemAssigned"
  }
}

# --- Policy: Associate DCR with Windows VMs ---
resource "azurerm_subscription_policy_assignment" "dcr_windows" {
  name                 = "${var.customer_name}-assoc-dcr-windows"
  display_name         = "[${var.customer_name}] Associate Windows DCR"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/eab1f514-22e3-42e3-9a1f-e1dc9199355c"
  enforcement_mode     = true
  location             = "eastus2"

  parameters = jsonencode({
    dcrResourceId = {
      value = var.dcr_windows_id
    }
  })

  identity {
    type = "SystemAssigned"
  }
}

# --- Policy: Associate DCR with Linux VMs ---
resource "azurerm_subscription_policy_assignment" "dcr_linux" {
  name                 = "${var.customer_name}-assoc-dcr-linux"
  display_name         = "[${var.customer_name}] Associate Linux DCR"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/58e891b9-ce13-4ac3-86e4-ac3e1f20cb07"
  enforcement_mode     = true
  location             = "eastus2"

  parameters = jsonencode({
    dcrResourceId = {
      value = var.dcr_linux_id
    }
  })

  identity {
    type = "SystemAssigned"
  }
}

# --- Data source ---
data "azurerm_subscription" "current" {}
