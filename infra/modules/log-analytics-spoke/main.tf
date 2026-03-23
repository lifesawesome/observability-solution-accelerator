# ============================================================================
# Log Analytics Spoke Workspace Module
# Deploys a Log Analytics workspace for a single customer (spoke)
# with Data Collection Rules, retention policies, and RBAC
# ============================================================================

resource "azurerm_log_analytics_workspace" "this" {
  name                               = var.workspace_name
  location                           = var.location
  resource_group_name                = var.resource_group_name
  sku                                = var.sku
  retention_in_days                  = var.retention_in_days
  reservation_capacity_in_gb_per_day = var.sku == "CapacityReservation" ? var.capacity_reservation_level : null
  tags                               = var.tags

  # Enable resource-context access (recommended for multi-tenant)
  allow_resource_only_permissions = true
}

# ============================================================================
# Data Collection Rule - Windows Performance + Event Logs
# ============================================================================
resource "azurerm_monitor_data_collection_rule" "windows_perf" {
  name                = "${var.workspace_name}-dcr-windows-perf"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.this.id
      name                  = "la-destination"
    }
  }

  data_flow {
    streams      = ["Microsoft-Perf", "Microsoft-Event"]
    destinations = ["la-destination"]
  }

  data_sources {
    performance_counter {
      name                          = "perfCounters"
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "\\Processor Information(_Total)\\% Processor Time",
        "\\Memory\\Available Bytes",
        "\\Memory\\% Committed Bytes In Use",
        "\\LogicalDisk(_Total)\\% Free Space",
        "\\LogicalDisk(_Total)\\Avg. Disk sec/Read",
        "\\LogicalDisk(_Total)\\Avg. Disk sec/Write",
        "\\Network Interface(*)\\Bytes Total/sec",
      ]
    }

    windows_event_log {
      name    = "windowsEvents"
      streams = ["Microsoft-Event"]
      x_path_queries = [
        "Application!*[System[(Level=1 or Level=2 or Level=3)]]",
        "System!*[System[(Level=1 or Level=2 or Level=3)]]",
        "Security!*[System[(band(Keywords,13510798882111488))]]",
      ]
    }
  }
}

# ============================================================================
# Data Collection Rule - Linux Syslog + Performance
# ============================================================================
resource "azurerm_monitor_data_collection_rule" "linux_perf" {
  name                = "${var.workspace_name}-dcr-linux-perf"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.this.id
      name                  = "la-destination"
    }
  }

  data_flow {
    streams      = ["Microsoft-Perf", "Microsoft-Syslog"]
    destinations = ["la-destination"]
  }

  data_sources {
    performance_counter {
      name                          = "linuxPerf"
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "\\Processor(*)\\% Processor Time",
        "\\Memory(*)\\Available MBytes Memory",
        "\\Memory(*)\\% Used Memory",
        "\\LogicalDisk(*)\\% Free Space",
        "\\LogicalDisk(*)\\% Used Space",
      ]
    }

    syslog {
      name           = "syslog"
      streams        = ["Microsoft-Syslog"]
      facility_names = ["auth", "authpriv", "daemon", "kern", "syslog"]
      log_levels     = ["Alert", "Critical", "Emergency", "Error", "Warning"]
    }
  }
}
