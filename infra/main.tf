# ============================================================================
# Main Orchestrator - Deploys full observability stack for a customer
# ============================================================================

locals {
  name_prefix = "obs-${var.customer_name}"
  common_tags = merge(var.tags, {
    project  = "observability-accelerator"
    customer = var.customer_name
  })
}

# --- Resource Group Data Source ---
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# ============================================================================
# Layer 2a: IT Data Platform — Log Analytics Spoke Workspace
# ============================================================================
module "log_analytics" {
  source = "./modules/log-analytics-spoke"

  resource_group_name        = data.azurerm_resource_group.main.name
  location                   = var.location
  workspace_name             = "la-${var.customer_name}-obs"
  sku                        = var.workspace_sku
  capacity_reservation_level = var.capacity_reservation_level
  retention_in_days          = var.workspace_retention_days
  tags                       = local.common_tags
}

# ============================================================================
# Layer 2a: Application Insights (one per app)
# ============================================================================
module "app_insights" {
  source   = "./modules/app-insights"
  for_each = toset(var.app_insights_apps)

  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  app_insights_name   = "ai-${var.customer_name}-${each.key}"
  workspace_id        = module.log_analytics.workspace_id
  tags                = local.common_tags
}

# ============================================================================
# Layer 2a: Microsoft Sentinel
# ============================================================================
module "sentinel" {
  source = "./modules/sentinel"
  count  = var.enable_sentinel ? 1 : 0

  resource_group_name        = data.azurerm_resource_group.main.name
  workspace_name             = module.log_analytics.workspace_name
  workspace_id               = module.log_analytics.workspace_id
  log_analytics_workspace_id = module.log_analytics.workspace_id
  tags                       = local.common_tags
}

# ============================================================================
# Layer 5: Action Groups (alerts → ServiceNow / email / Teams)
# ============================================================================
module "action_groups" {
  source = "./modules/action-groups"

  resource_group_name    = data.azurerm_resource_group.main.name
  customer_name          = var.customer_name
  email_recipients       = var.alert_email_recipients
  servicenow_webhook_uri = var.servicenow_webhook_uri
  tags                   = local.common_tags
}

# ============================================================================
# Layer 3: Alert Rules (dynamic thresholds)
# ============================================================================
module "alert_rules" {
  source = "./modules/alert-rules"

  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  workspace_id        = module.log_analytics.workspace_id
  action_group_id     = module.action_groups.critical_action_group_id
  customer_name       = var.customer_name
  alert_thresholds    = var.alert_thresholds
  tags                = local.common_tags
}

# ============================================================================
# Governance: Azure Policy Initiative — "Monitor Everything"
# ============================================================================
module "policy_initiative" {
  source = "./modules/policy-initiative"

  workspace_id   = module.log_analytics.workspace_id
  dcr_windows_id = module.log_analytics.dcr_windows_perf_id
  dcr_linux_id   = module.log_analytics.dcr_linux_perf_id
  customer_name  = var.customer_name
  location       = var.location
}

# ============================================================================
# Multi-tenant: Azure Lighthouse (optional)
# ============================================================================
module "lighthouse" {
  source = "./modules/lighthouse"
  count  = var.enable_lighthouse ? 1 : 0

  customer_name    = var.customer_name
  hub_tenant_id    = var.lighthouse_hub_tenant_id
  hub_principal_id = var.lighthouse_hub_principal_id
}

# ============================================================================
# Layer 1b: IoT Hub for OT/IoT (optional)
# ============================================================================
module "iot_hub" {
  source = "./modules/iot-hub"
  count  = var.enable_iot_hub ? 1 : 0

  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  iot_hub_name        = "iot-${var.customer_name}-obs"
  sku                 = var.iot_hub_sku
  capacity            = var.iot_hub_capacity
  tags                = local.common_tags
}

# ============================================================================
# Network Observability (optional)
# ============================================================================
module "network_observability" {
  source = "./modules/network-observability"
  count  = var.enable_network_observability ? 1 : 0

  resource_group_name     = data.azurerm_resource_group.main.name
  location                = var.location
  workspace_id            = module.log_analytics.workspace_id
  workspace_customer_id   = module.log_analytics.workspace_customer_id
  customer_name           = var.customer_name
  nsg_ids                 = var.nsg_ids
  flow_log_retention_days = var.flow_log_retention_days
  tags                    = local.common_tags
}

# ============================================================================
# AMBA: Azure Monitor Baseline Alerts — Service-Specific Alert Packs (optional)
# ============================================================================
module "amba_alerts" {
  source = "./modules/amba-alerts"
  count  = var.enable_amba ? 1 : 0

  resource_group_name      = data.azurerm_resource_group.main.name
  location                 = var.location
  workspace_id             = module.log_analytics.workspace_id
  critical_action_group_id = module.action_groups.critical_action_group_id
  warning_action_group_id  = module.action_groups.warning_action_group_id
  customer_name            = var.customer_name
  amba_services            = var.amba_services
  thresholds               = var.amba_thresholds
  tags                     = local.common_tags
}

# ============================================================================
# AKS Observability — Container Insights + AKS Alerts (optional)
# ============================================================================
module "aks_observability" {
  source = "./modules/aks-observability"
  count  = var.enable_aks ? 1 : 0

  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  aks_cluster_id      = var.aks_cluster_id
  workspace_id        = module.log_analytics.workspace_id
  action_group_id     = module.action_groups.critical_action_group_id
  customer_name       = var.customer_name
  tags                = local.common_tags
}

# ============================================================================
# AMPLS: Azure Monitor Private Link Scope (optional)
# Enables private connectivity for Log Analytics + App Insights
# Auto-detected by discovery scanner when resources have publicNetworkAccess=Disabled
# ============================================================================
module "ampls" {
  source = "./modules/ampls"
  count  = var.enable_ampls ? 1 : 0

  resource_group_name      = data.azurerm_resource_group.main.name
  location                 = var.location
  ampls_name               = "ampls-${var.customer_name}-obs"
  workspace_id             = module.log_analytics.workspace_id
  app_insights_ids         = { for k, v in module.app_insights : k => v.id }
  subnet_id                = var.ampls_subnet_id
  vnet_id                  = var.ampls_vnet_id
  ingestion_access_mode    = var.ampls_ingestion_access_mode
  query_access_mode        = var.ampls_query_access_mode
  create_private_dns_zones = var.ampls_create_dns_zones
  tags                     = local.common_tags
}

# ============================================================================
# Layer 4: Auto-Generated Workbooks (optional)
# ============================================================================
# Deploy workbooks from the generated-workbooks/ directory.
# Run discovery/generate_workbooks.py BEFORE terraform apply to populate
# the workbook_files map. See docs/onboarding-playbook.md for the full flow.
# ============================================================================
module "workbooks" {
  source = "./modules/workbooks"
  count  = var.enable_workbooks ? 1 : 0

  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  workspace_id        = module.log_analytics.workspace_id
  workbook_files      = var.workbook_files
  tags                = local.common_tags
}

# ============================================================================
# Diagnostic Settings — Wire discovered resources to Log Analytics
# Auto-populated from discovery scan; sends logs + metrics from each resource
# ============================================================================
module "diagnostic_settings" {
  source = "./modules/diagnostic-settings"
  count  = length(var.diagnostic_resource_ids) > 0 ? 1 : 0

  resource_group_name         = data.azurerm_resource_group.main.name
  workspace_id                = module.log_analytics.workspace_id
  customer_name               = var.customer_name
  resource_ids                = var.diagnostic_resource_ids
  log_categories_per_resource = var.diagnostic_log_categories
}
