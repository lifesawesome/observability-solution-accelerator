# ============================================================================
# Microsoft Sentinel Module
# Enables Sentinel on an existing Log Analytics workspace
# Configures UEBA and core data connectors
# ============================================================================

resource "azurerm_sentinel_log_analytics_workspace_onboarding" "this" {
  workspace_id = var.log_analytics_workspace_id
}

# ============================================================================
# Sentinel Analytics Rules - Built-in rule templates
# ============================================================================

# Brute force detection
resource "azurerm_sentinel_alert_rule_scheduled" "brute_force" {
  name                       = "brute-force-detection"
  display_name               = "Brute Force Attack Against Azure Portal"
  log_analytics_workspace_id = var.log_analytics_workspace_id
  severity                   = "High"
  query_frequency            = "PT5M"
  query_period               = "PT1H"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  enabled                    = true

  query = <<-QUERY
    SigninLogs
    | where TimeGenerated > ago(1h)
    | where ResultType == "50126" // Invalid username or password
    | summarize FailedAttempts = count(), DistinctAccounts = dcount(UserPrincipalName) by IPAddress, bin(TimeGenerated, 5m)
    | where FailedAttempts > 10
    | project TimeGenerated, IPAddress, FailedAttempts, DistinctAccounts
  QUERY

  tactics = ["CredentialAccess"]

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.this]
}

# Anomalous Azure Activity
resource "azurerm_sentinel_alert_rule_scheduled" "anomalous_azure_activity" {
  name                       = "anomalous-azure-activity"
  display_name               = "Anomalous Azure Resource Activity"
  log_analytics_workspace_id = var.log_analytics_workspace_id
  severity                   = "Medium"
  query_frequency            = "PT1H"
  query_period               = "PT24H"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  enabled                    = true

  query = <<-QUERY
    AzureActivity
    | where TimeGenerated > ago(24h)
    | where OperationNameValue endswith "DELETE" or OperationNameValue endswith "WRITE"
    | where ActivityStatusValue == "Success"
    | summarize OperationCount = count() by Caller, OperationNameValue, bin(TimeGenerated, 1h)
    | where OperationCount > 20
  QUERY

  tactics = ["Impact", "DefenseEvasion"]

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.this]
}
