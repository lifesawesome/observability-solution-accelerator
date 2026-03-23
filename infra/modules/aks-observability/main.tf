# ============================================================================
# AKS Observability Module
# Enables Container Insights, diagnostic settings, and recommended AKS alerts
# ============================================================================

# --- Enable Container Insights via diagnostic settings ---
resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "${var.customer_name}-aks-diag"
  target_resource_id         = var.aks_cluster_id
  log_analytics_workspace_id = var.workspace_id

  # Container Insights log categories
  enabled_log {
    category = "kube-apiserver"
  }
  enabled_log {
    category = "kube-controller-manager"
  }
  enabled_log {
    category = "kube-scheduler"
  }
  enabled_log {
    category = "kube-audit-admin"
  }
  enabled_log {
    category = "guard"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# --- Data Collection Rule for Container Insights ---
resource "azurerm_monitor_data_collection_rule" "aks_ci" {
  name                = "${var.customer_name}-aks-ci-dcr"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  destinations {
    log_analytics {
      workspace_resource_id = var.workspace_id
      name                  = "ciworkspace"
    }
  }

  data_flow {
    streams      = ["Microsoft-ContainerInsights-Group-Default"]
    destinations = ["ciworkspace"]
  }

  data_sources {
    extension {
      name           = "ContainerInsightsExtension"
      extension_name = "ContainerInsights"
      streams        = ["Microsoft-ContainerInsights-Group-Default"]
      extension_json = jsonencode({
        dataCollectionSettings = {
          interval               = "1m"
          namespaceFilteringMode = "Off"
          enableContainerLogV2   = true
        }
      })
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "aks_ci" {
  name                    = "${var.customer_name}-aks-ci-dcra"
  target_resource_id      = var.aks_cluster_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.aks_ci.id
}

# --- AKS-Specific Alert Rules ---

# OOMKilled containers
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "aks_oom_killed" {
  name                = "${var.customer_name}-aks-oom-killed"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "AKS OOMKilled Containers"
  description         = "Containers terminated due to out-of-memory conditions"
  severity            = 1
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AKS: OOMKilled container detection
      KubePodInventory
      | where TimeGenerated > ago(15m)
      | where ContainerStatusReason == "OOMKilled"
      | summarize OOMCount = count() by ClusterName, Namespace, Name, ContainerName
      | where OOMCount > 0
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.action_group_id]
  }
}

# Persistent Volume usage high
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "aks_pv_usage" {
  name                = "${var.customer_name}-aks-pv-usage"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "AKS Persistent Volume Usage > 85%"
  description         = "Persistent volume disk usage nearing capacity"
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT15M"
  window_duration       = "PT30M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AKS: PV usage approaching capacity
      InsightsMetrics
      | where TimeGenerated > ago(30m)
      | where Name == "pvUsedBytes"
      | extend PVName = tostring(Tags["pvName"])
      | extend Namespace = tostring(Tags["podNamespace"])
      | summarize UsedBytes = avg(Val) by PVName, Namespace
      | join kind=inner (
        InsightsMetrics
        | where Name == "pvCapacityBytes"
        | extend PVName = tostring(Tags["pvName"])
        | summarize CapacityBytes = max(Val) by PVName
      ) on PVName
      | extend UsagePct = UsedBytes / CapacityBytes * 100
      | where UsagePct > 85
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.action_group_id]
  }
}

# Node NotReady
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "aks_node_not_ready" {
  name                = "${var.customer_name}-aks-node-notready"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "AKS Node Not Ready"
  description         = "One or more AKS nodes in NotReady state"
  severity            = 1
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AKS: Node not ready
      KubeNodeInventory
      | where TimeGenerated > ago(15m)
      | where Status == "NotReady"
      | summarize NotReadyCount = dcount(Computer) by ClusterName
      | where NotReadyCount > 0
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.action_group_id]
  }
}

# Pod pending too long
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "aks_pod_pending" {
  name                = "${var.customer_name}-aks-pod-pending"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "AKS Pods Stuck in Pending"
  description         = "Pods unable to be scheduled for more than 10 minutes"
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT5M"
  window_duration       = "PT15M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AKS: Pods stuck in pending state
      KubePodInventory
      | where TimeGenerated > ago(15m)
      | where PodStatus == "Pending"
      | summarize arg_max(TimeGenerated, *) by Name, Namespace, ClusterName
      | where datetime_diff('minute', now(), PodCreationTimeStamp) > 10
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.action_group_id]
  }
}

# Container restart loop
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "aks_container_restarts" {
  name                = "${var.customer_name}-aks-restarts"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "AKS Container Excessive Restarts"
  description         = "Container restarting repeatedly (>5 restarts in 30m)"
  severity            = 2
  enabled             = true
  tags                = var.tags

  scopes                = [var.workspace_id]
  evaluation_frequency  = "PT15M"
  window_duration       = "PT30M"
  target_resource_types = ["Microsoft.OperationalInsights/workspaces"]

  criteria {
    query                   = <<-QUERY
      // AKS: Excessive container restarts
      KubePodInventory
      | where TimeGenerated > ago(30m)
      | summarize RestartCount = max(ContainerRestartCount) by ClusterName, Namespace, Name, ContainerName
      | where RestartCount > 5
    QUERY
    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"
  }

  action {
    action_groups = [var.action_group_id]
  }
}
