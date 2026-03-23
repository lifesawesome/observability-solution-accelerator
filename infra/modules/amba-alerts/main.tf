# ============================================================================
# AMBA (Azure Monitor Baseline Alerts) Module
# Service-specific alert packs aligned with Azure Monitor best practices
# Customers select which services to monitor via var.amba_services
# ============================================================================

locals {
  # Normalize service list for lookups
  enable_vm           = contains(var.amba_services, "vm")
  enable_sql          = contains(var.amba_services, "sql")
  enable_appservice   = contains(var.amba_services, "appservice")
  enable_aks          = contains(var.amba_services, "aks")
  enable_storage      = contains(var.amba_services, "storage")
  enable_keyvault     = contains(var.amba_services, "keyvault")
  enable_eventhub     = contains(var.amba_services, "eventhub")
  enable_cosmosdb     = contains(var.amba_services, "cosmosdb")
  enable_databricks   = contains(var.amba_services, "databricks")
  enable_loadbalancer = contains(var.amba_services, "loadbalancer")
}

# ============================================================================
# VM Baseline Alerts (metric-based)
# ============================================================================

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "vm_cpu_high" {
  count               = local.enable_vm ? 1 : 0
  name                = "${var.customer_name}-amba-vm-cpu-high"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] VM CPU > ${var.thresholds.vm_cpu_percent}%"
  description         = "AMBA baseline: VM CPU utilization exceeded threshold"
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: VM CPU utilization baseline alert
      Perf
      | where TimeGenerated > ago(15m)
      | where ObjectName == "Processor" and CounterName == "% Processor Time" and InstanceName == "_Total"
      | summarize AvgCPU = avg(CounterValue) by Computer
      | where AvgCPU > ${var.thresholds.vm_cpu_percent}
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.warning_action_group_id]
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "vm_os_disk_iops" {
  count               = local.enable_vm ? 1 : 0
  name                = "${var.customer_name}-amba-vm-disk-iops"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] VM Disk IOPS Saturation"
  description         = "AMBA baseline: Disk transfers/sec exceeding capacity"
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT15M"
  window_duration       = "PT30M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: VM disk IOPS saturation
      Perf
      | where TimeGenerated > ago(30m)
      | where ObjectName == "LogicalDisk" and CounterName == "Disk Transfers/sec"
      | where InstanceName != "_Total"
      | summarize AvgIOPS = avg(CounterValue) by Computer, InstanceName
      | where AvgIOPS > ${var.thresholds.vm_disk_iops}
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.warning_action_group_id]
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "vm_network_errors" {
  count               = local.enable_vm ? 1 : 0
  name                = "${var.customer_name}-amba-vm-net-errors"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] VM Network Interface Errors"
  description         = "AMBA baseline: Network adapter errors detected"
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT15M"
  window_duration       = "PT30M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: Network adapter errors
      Perf
      | where TimeGenerated > ago(30m)
      | where ObjectName == "Network Adapter" and CounterName == "Packets Received Errors"
      | summarize TotalErrors = sum(CounterValue) by Computer
      | where TotalErrors > 100
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.warning_action_group_id]
  }
}

# ============================================================================
# Azure SQL Database Baseline Alerts
# ============================================================================

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "sql_dtu_high" {
  count               = local.enable_sql ? 1 : 0
  name                = "${var.customer_name}-amba-sql-dtu"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] SQL DTU/CPU > ${var.thresholds.sql_dtu_percent}%"
  description         = "AMBA baseline: SQL Database DTU or vCore utilization high"
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: SQL DTU/CPU utilization
      AzureMetrics
      | where TimeGenerated > ago(15m)
      | where ResourceProvider == "MICROSOFT.SQL"
      | where MetricName == "dtu_consumption_percent" or MetricName == "cpu_percent"
      | summarize AvgDTU = avg(Average) by Resource, MetricName
      | where AvgDTU > ${var.thresholds.sql_dtu_percent}
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.warning_action_group_id]
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "sql_deadlocks" {
  count               = local.enable_sql ? 1 : 0
  name                = "${var.customer_name}-amba-sql-deadlocks"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] SQL Deadlocks Detected"
  description         = "AMBA baseline: SQL Database deadlocks occurring"
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: SQL deadlock detection
      AzureMetrics
      | where TimeGenerated > ago(15m)
      | where ResourceProvider == "MICROSOFT.SQL"
      | where MetricName == "deadlock"
      | summarize TotalDeadlocks = sum(Total) by Resource
      | where TotalDeadlocks > 0
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.critical_action_group_id]
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "sql_failed_connections" {
  count               = local.enable_sql ? 1 : 0
  name                = "${var.customer_name}-amba-sql-conn-fail"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] SQL Failed Connections"
  description         = "AMBA baseline: SQL Database connection failures elevated"
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: SQL failed connections
      AzureMetrics
      | where TimeGenerated > ago(15m)
      | where ResourceProvider == "MICROSOFT.SQL"
      | where MetricName == "connection_failed"
      | summarize TotalFailed = sum(Total) by Resource
      | where TotalFailed > ${var.thresholds.sql_failed_connections}
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.warning_action_group_id]
  }
}

# ============================================================================
# App Service Baseline Alerts
# ============================================================================

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "appservice_http_5xx" {
  count               = local.enable_appservice ? 1 : 0
  name                = "${var.customer_name}-amba-appsvc-5xx"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] App Service HTTP 5xx Errors"
  description         = "AMBA baseline: App Service returning server errors"
  severity            = 1
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: App Service HTTP 5xx errors
      AzureMetrics
      | where TimeGenerated > ago(15m)
      | where ResourceProvider == "MICROSOFT.WEB"
      | where MetricName == "Http5xx"
      | summarize Total5xx = sum(Total) by Resource
      | where Total5xx > ${var.thresholds.appservice_http_5xx_count}
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.critical_action_group_id]
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "appservice_response_time" {
  count               = local.enable_appservice ? 1 : 0
  name                = "${var.customer_name}-amba-appsvc-latency"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] App Service Response Time > ${var.thresholds.appservice_response_time_sec}s"
  description         = "AMBA baseline: App Service response time degraded"
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: App Service high response time
      AzureMetrics
      | where TimeGenerated > ago(15m)
      | where ResourceProvider == "MICROSOFT.WEB"
      | where MetricName == "HttpResponseTime"
      | summarize AvgResponseSec = avg(Average) by Resource
      | where AvgResponseSec > ${var.thresholds.appservice_response_time_sec}
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.warning_action_group_id]
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "appservice_cpu_high" {
  count               = local.enable_appservice ? 1 : 0
  name                = "${var.customer_name}-amba-appsvc-cpu"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] App Service CPU > 85%"
  description         = "AMBA baseline: App Service plan CPU utilization high"
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: App Service CPU utilization
      AzureMetrics
      | where TimeGenerated > ago(15m)
      | where ResourceProvider == "MICROSOFT.WEB"
      | where MetricName == "CpuPercentage"
      | summarize AvgCPU = avg(Average) by Resource
      | where AvgCPU > 85
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.warning_action_group_id]
  }
}

# ============================================================================
# AKS Baseline Alerts
# ============================================================================

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "aks_node_cpu" {
  count               = local.enable_aks ? 1 : 0
  name                = "${var.customer_name}-amba-aks-node-cpu"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] AKS Node CPU > ${var.thresholds.aks_node_cpu_percent}%"
  description         = "AMBA baseline: AKS node CPU utilization high"
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: AKS node CPU pressure
      KubeNodeInventory
      | where TimeGenerated > ago(15m)
      | distinct ClusterName, Computer
      | join kind=inner (
        Perf
        | where TimeGenerated > ago(15m)
        | where ObjectName == "K8SNode" and CounterName == "cpuUsageNanoCores"
        | summarize AvgCPU = avg(CounterValue) / 1000000000 * 100 by Computer
      ) on Computer
      | where AvgCPU > ${var.thresholds.aks_node_cpu_percent}
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.warning_action_group_id]
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "aks_node_memory" {
  count               = local.enable_aks ? 1 : 0
  name                = "${var.customer_name}-amba-aks-node-mem"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] AKS Node Memory > ${var.thresholds.aks_node_memory_percent}%"
  description         = "AMBA baseline: AKS node memory utilization high"
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: AKS node memory pressure
      KubeNodeInventory
      | where TimeGenerated > ago(15m)
      | distinct ClusterName, Computer
      | join kind=inner (
        Perf
        | where TimeGenerated > ago(15m)
        | where ObjectName == "K8SNode" and CounterName == "memoryWorkingSetBytes"
        | summarize AvgMem = avg(CounterValue) by Computer
        | join kind=inner (
          Perf | where ObjectName == "K8SNode" and CounterName == "memoryCapacityBytes"
          | summarize MemCap = max(CounterValue) by Computer
        ) on Computer
        | extend MemPct = AvgMem / MemCap * 100
      ) on Computer
      | where MemPct > ${var.thresholds.aks_node_memory_percent}
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.warning_action_group_id]
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "aks_pod_failures" {
  count               = local.enable_aks ? 1 : 0
  name                = "${var.customer_name}-amba-aks-pod-fail"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] AKS Pod Failures / CrashLoopBackOff"
  description         = "AMBA baseline: Pods in failed state or restart loop"
  severity            = 1
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: AKS pod failures and crash loops
      KubePodInventory
      | where TimeGenerated > ago(15m)
      | where PodStatus in ("Failed", "Unknown")
        or ContainerStatusReason in ("CrashLoopBackOff", "Error", "OOMKilled")
      | summarize FailCount = count() by ClusterName, Namespace, Name, PodStatus, ContainerStatusReason
      | where FailCount > 0
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.critical_action_group_id]
  }
}

# ============================================================================
# Azure Storage Baseline Alerts
# ============================================================================

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "storage_availability" {
  count               = local.enable_storage ? 1 : 0
  name                = "${var.customer_name}-amba-storage-avail"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] Storage Account Availability < 99.9%"
  description         = "AMBA baseline: Storage account availability degraded"
  severity            = 1
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: Storage availability
      AzureMetrics
      | where TimeGenerated > ago(15m)
      | where ResourceProvider == "MICROSOFT.STORAGE"
      | where MetricName == "Availability"
      | summarize AvgAvail = avg(Average) by Resource
      | where AvgAvail < 99.9
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.critical_action_group_id]
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "storage_throttling" {
  count               = local.enable_storage ? 1 : 0
  name                = "${var.customer_name}-amba-storage-throttle"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] Storage Throttling Detected"
  description         = "AMBA baseline: Storage account requests being throttled"
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: Storage throttling (HTTP 429/503)
      StorageBlobLogs
      | where TimeGenerated > ago(15m)
      | where StatusCode in (429, 503)
      | summarize ThrottleCount = count() by AccountName = tostring(split(_ResourceId, "/")[-1])
      | where ThrottleCount > ${var.thresholds.storage_throttle_count}
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.warning_action_group_id]
  }
}

# ============================================================================
# Key Vault Baseline Alerts
# ============================================================================

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "keyvault_availability" {
  count               = local.enable_keyvault ? 1 : 0
  name                = "${var.customer_name}-amba-kv-avail"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] Key Vault Availability < 99%"
  description         = "AMBA baseline: Key Vault service availability degraded"
  severity            = 1
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: Key Vault availability
      AzureMetrics
      | where TimeGenerated > ago(15m)
      | where ResourceProvider == "MICROSOFT.KEYVAULT"
      | where MetricName == "Availability"
      | summarize AvgAvail = avg(Average) by Resource
      | where AvgAvail < 99
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.critical_action_group_id]
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "keyvault_latency" {
  count               = local.enable_keyvault ? 1 : 0
  name                = "${var.customer_name}-amba-kv-latency"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] Key Vault High Latency"
  description         = "AMBA baseline: Key Vault operations taking too long"
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: Key Vault latency
      AzureMetrics
      | where TimeGenerated > ago(15m)
      | where ResourceProvider == "MICROSOFT.KEYVAULT"
      | where MetricName == "ServiceApiLatency"
      | summarize AvgLatencyMs = avg(Average) by Resource
      | where AvgLatencyMs > 1000
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.warning_action_group_id]
  }
}

# ============================================================================
# Event Hubs Baseline Alerts
# ============================================================================

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "eventhub_throttling" {
  count               = local.enable_eventhub ? 1 : 0
  name                = "${var.customer_name}-amba-eh-throttle"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] Event Hub Throttled Requests"
  description         = "AMBA baseline: Event Hub requests being throttled"
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: Event Hub throttling
      AzureMetrics
      | where TimeGenerated > ago(15m)
      | where ResourceProvider == "MICROSOFT.EVENTHUB"
      | where MetricName == "ThrottledRequests"
      | summarize TotalThrottled = sum(Total) by Resource
      | where TotalThrottled > 0
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.warning_action_group_id]
  }
}

# ============================================================================
# Cosmos DB Baseline Alerts
# ============================================================================

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "cosmosdb_ru_consumption" {
  count               = local.enable_cosmosdb ? 1 : 0
  name                = "${var.customer_name}-amba-cosmos-ru"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] Cosmos DB RU Consumption > ${var.thresholds.cosmosdb_ru_percent}%"
  description         = "AMBA baseline: Cosmos DB request unit consumption high"
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: Cosmos DB RU consumption
      AzureMetrics
      | where TimeGenerated > ago(15m)
      | where ResourceProvider == "MICROSOFT.DOCUMENTDB"
      | where MetricName == "NormalizedRUConsumption"
      | summarize AvgRU = avg(Maximum) by Resource
      | where AvgRU > ${var.thresholds.cosmosdb_ru_percent}
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.warning_action_group_id]
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "cosmosdb_429s" {
  count               = local.enable_cosmosdb ? 1 : 0
  name                = "${var.customer_name}-amba-cosmos-429"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] Cosmos DB Rate Limited (429)"
  description         = "AMBA baseline: Cosmos DB requests being rate limited"
  severity            = 1
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: Cosmos DB throttling (429)
      AzureMetrics
      | where TimeGenerated > ago(15m)
      | where ResourceProvider == "MICROSOFT.DOCUMENTDB"
      | where MetricName == "TotalRequestUnits"
      | where Average == 429
      | summarize Throttled = count() by Resource
      | where Throttled > 0
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.critical_action_group_id]
  }
}

# ============================================================================
# Databricks Baseline Alerts
# ============================================================================

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "databricks_job_failures" {
  count               = local.enable_databricks ? 1 : 0
  name                = "${var.customer_name}-amba-dbr-job-fail"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] Databricks Job Failures"
  description         = "AMBA baseline: Databricks jobs failing"
  severity            = 1
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT15M"
  window_duration       = "PT30M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: Databricks job failures
      DatabricksJobs
      | where TimeGenerated > ago(30m)
      | where ActionName == "runFailed"
      | summarize FailCount = count() by WorkspaceName = tostring(split(_ResourceId, "/")[-1])
      | where FailCount > 0
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.critical_action_group_id]
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "databricks_cluster_errors" {
  count               = local.enable_databricks ? 1 : 0
  name                = "${var.customer_name}-amba-dbr-cluster"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] Databricks Cluster Errors"
  description         = "AMBA baseline: Databricks cluster start/termination errors"
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT15M"
  window_duration       = "PT30M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: Databricks cluster errors
      DatabricksClusters
      | where TimeGenerated > ago(30m)
      | where ActionName in ("startResult", "createResult", "resizeResult")
      | where Response has "error" or Response has "TERMINATED"
      | summarize ErrorCount = count() by WorkspaceName = tostring(split(_ResourceId, "/")[-1]), ActionName
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.warning_action_group_id]
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "databricks_warehouse_queuing" {
  count               = local.enable_databricks ? 1 : 0
  name                = "${var.customer_name}-amba-dbr-warehouse"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] Databricks SQL Warehouse Query Queuing"
  description         = "AMBA baseline: SQL Warehouse queries queuing due to capacity"
  severity            = 3
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT15M"
  window_duration       = "PT30M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: Databricks SQL Warehouse query queuing
      DatabricksSQLPermissions
      | where TimeGenerated > ago(30m)
      | where ActionName == "commandSubmit"
      | summarize QueuedQueries = count() by WorkspaceName = tostring(split(_ResourceId, "/")[-1])
      | where QueuedQueries > 50
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.warning_action_group_id]
  }
}

# ============================================================================
# Load Balancer Baseline Alerts
# ============================================================================

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "lb_health_probe_down" {
  count               = local.enable_loadbalancer ? 1 : 0
  name                = "${var.customer_name}-amba-lb-probe"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] Load Balancer Health Probe Down"
  description         = "AMBA baseline: Backend pool health probe status degraded"
  severity            = 1
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: Load Balancer health probe failures
      AzureMetrics
      | where TimeGenerated > ago(15m)
      | where ResourceProvider == "MICROSOFT.NETWORK"
      | where MetricName == "DipAvailability"
      | summarize AvgHealth = avg(Average) by Resource
      | where AvgHealth < 90
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.critical_action_group_id]
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "lb_snat_exhaustion" {
  count               = local.enable_loadbalancer ? 1 : 0
  name                = "${var.customer_name}-amba-lb-snat"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "[AMBA] Load Balancer SNAT Port Exhaustion"
  description         = "AMBA baseline: SNAT port allocation failures occurring"
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AMBA: Load Balancer SNAT exhaustion
      AzureMetrics
      | where TimeGenerated > ago(15m)
      | where ResourceProvider == "MICROSOFT.NETWORK"
      | where MetricName == "SnatConnectionCount"
      | where Average > 0
      | summarize FailedSnat = sumif(Total, Average == 2) by Resource
      | where FailedSnat > 0
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.warning_action_group_id]
  }
}
