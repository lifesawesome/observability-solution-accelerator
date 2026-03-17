# ============================================================================
# Alert Rules Module
# Deploys dynamic threshold and log-based alert rules
# ============================================================================

# --- Heartbeat (VM availability) ---
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "vm_heartbeat" {
  name                = "${var.customer_name}-vm-heartbeat-loss"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "VM Heartbeat Loss Detected"
  description         = "Alerts when a VM stops sending heartbeats for more than 5 minutes"
  severity            = 1
  enabled             = true
  tags                = var.tags

  scopes                   = [var.workspace_id]
  evaluation_frequency     = "PT5M"
  window_duration          = "PT15M"
  target_resource_types    = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query = <<-QUERY
      Heartbeat
      | summarize LastHeartbeat = max(TimeGenerated) by Computer
      | where LastHeartbeat < ago(5m)
      | project Computer, LastHeartbeat, MinutesSinceHeartbeat = datetime_diff('minute', now(), LastHeartbeat)
    QUERY
    operator             = "GreaterThan"
    threshold            = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.action_group_id]
  }
}

# --- High Error Rate (Application) ---
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "app_error_rate" {
  name                = "${var.customer_name}-app-error-rate"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "Application Error Rate Spike"
  description         = "Alerts on elevated exception rate in Application Insights"
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                   = [var.workspace_id]
  evaluation_frequency     = "PT5M"
  window_duration          = "PT15M"
  target_resource_types    = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query = <<-QUERY
      AppExceptions
      | where TimeGenerated > ago(15m)
      | summarize ExceptionCount = count() by AppRoleName, bin(TimeGenerated, 5m)
      | where ExceptionCount > 50
      | project TimeGenerated, AppRoleName, ExceptionCount
    QUERY
    operator             = "GreaterThan"
    threshold            = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.action_group_id]
  }
}

# --- Disk Space Low ---
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "disk_space_low" {
  name                = "${var.customer_name}-disk-space-low"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "Disk Space Below 10% Free"
  description         = "Alerts when any disk drops below 10% free space"
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                   = [var.workspace_id]
  evaluation_frequency     = "PT15M"
  window_duration          = "PT30M"
  target_resource_types    = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query = <<-QUERY
      Perf
      | where TimeGenerated > ago(30m)
      | where ObjectName == "LogicalDisk" and CounterName == "% Free Space"
      | where InstanceName != "_Total" and InstanceName != "HarddiskVolume1"
      | summarize AvgFreeSpace = avg(CounterValue) by Computer, InstanceName
      | where AvgFreeSpace < 10
      | project Computer, InstanceName, AvgFreeSpace
    QUERY
    operator             = "GreaterThan"
    threshold            = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.action_group_id]
  }
}

# --- Memory Pressure ---
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "memory_pressure" {
  name                = "${var.customer_name}-memory-pressure"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "High Memory Usage Detected"
  description         = "Alerts when committed memory exceeds 90%"
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                   = [var.workspace_id]
  evaluation_frequency     = "PT5M"
  window_duration          = "PT15M"
  target_resource_types    = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query = <<-QUERY
      Perf
      | where TimeGenerated > ago(15m)
      | where ObjectName == "Memory" and CounterName == "% Committed Bytes In Use"
      | summarize AvgMemory = avg(CounterValue) by Computer
      | where AvgMemory > 90
      | project Computer, AvgMemory
    QUERY
    operator             = "GreaterThan"
    threshold            = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.action_group_id]
  }
}

# --- Anomaly Detection (KQL-based) ---
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "cpu_anomaly" {
  name                = "${var.customer_name}-cpu-anomaly"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "CPU Anomaly Detected (ML-based)"
  description         = "Uses KQL series_decompose_anomalies to detect CPU anomalies"
  severity            = 3
  enabled             = true
  tags                = var.tags

  scopes                   = [var.workspace_id]
  evaluation_frequency     = "PT30M"
  window_duration          = "PT6H"
  target_resource_types    = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query = <<-QUERY
      Perf
      | where TimeGenerated > ago(6h)
      | where ObjectName == "Processor" and CounterName == "% Processor Time" and InstanceName == "_Total"
      | summarize AvgCPU = avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
      | make-series CPUSeries = avg(AvgCPU) on TimeGenerated step 5m by Computer
      | extend (anomalies, score, baseline) = series_decompose_anomalies(CPUSeries, 1.5, -1, 'linefit')
      | mv-expand TimeGenerated to typeof(datetime), CPUSeries to typeof(double), anomalies to typeof(int), score to typeof(double)
      | where anomalies == 1 and score > 2.0
      | project TimeGenerated, Computer, CPUSeries, score
    QUERY
    operator             = "GreaterThan"
    threshold            = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.action_group_id]
  }
}
