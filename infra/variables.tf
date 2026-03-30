# ============================================================================
# Root Variables
# ============================================================================

variable "subscription_id" {
  description = "Azure subscription ID for deployment"
  type        = string
}

variable "customer_name" {
  description = "Customer name used for resource naming (lowercase, no spaces)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.customer_name))
    error_message = "Customer name must be lowercase alphanumeric with hyphens only."
  }
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "westus2"
}

variable "resource_group_name" {
  description = "Resource group name for the customer observability stack"
  type        = string
}

# --- Log Analytics ---
variable "workspace_sku" {
  description = "Log Analytics workspace SKU"
  type        = string
  default     = "PerGB2018"
  validation {
    condition     = contains(["PerGB2018", "CapacityReservation"], var.workspace_sku)
    error_message = "SKU must be PerGB2018 or CapacityReservation."
  }
}

variable "workspace_retention_days" {
  description = "Log Analytics interactive retention in days"
  type        = number
  default     = 90
  validation {
    condition     = var.workspace_retention_days >= 30 && var.workspace_retention_days <= 730
    error_message = "Retention must be between 30 and 730 days."
  }
}

variable "capacity_reservation_level" {
  description = "Capacity reservation in GB/day (only used when sku is CapacityReservation)"
  type        = number
  default     = 100
  validation {
    condition     = contains([100, 200, 300, 400, 500, 1000, 2000, 5000], var.capacity_reservation_level)
    error_message = "Must be one of: 100, 200, 300, 400, 500, 1000, 2000, 5000."
  }
}

# --- Feature Toggles ---
variable "enable_sentinel" {
  description = "Enable Microsoft Sentinel on the workspace"
  type        = bool
  default     = true
}

variable "enable_iot_hub" {
  description = "Deploy IoT Hub for OT/IoT observability"
  type        = bool
  default     = false
}

variable "enable_network_observability" {
  description = "Deploy Network Watcher and NSG flow logs"
  type        = bool
  default     = true
}

variable "enable_lighthouse" {
  description = "Configure Azure Lighthouse delegation to hub tenant"
  type        = bool
  default     = false
}

variable "enable_amba" {
  description = "Deploy AMBA (Azure Monitor Baseline Alerts) service-specific alert packs"
  type        = bool
  default     = false
}

variable "amba_services" {
  description = "List of Azure services to enable AMBA alerts for (vm, sql, appservice, aks, storage, keyvault, eventhub, cosmosdb, databricks, loadbalancer)"
  type        = list(string)
  default     = ["vm"]
}

variable "amba_thresholds" {
  description = "Tunable thresholds for AMBA service-specific alerts"
  type = object({
    vm_cpu_percent               = optional(number, 85)
    vm_disk_iops                 = optional(number, 500)
    sql_dtu_percent              = optional(number, 85)
    sql_failed_connections       = optional(number, 10)
    appservice_http_5xx_count    = optional(number, 10)
    appservice_response_time_sec = optional(number, 5)
    aks_node_cpu_percent         = optional(number, 80)
    aks_node_memory_percent      = optional(number, 80)
    storage_throttle_count       = optional(number, 10)
    cosmosdb_ru_percent          = optional(number, 80)
  })
  default = {}
}

variable "enable_aks" {
  description = "Deploy AKS Observability module (Container Insights + AKS alerts)"
  type        = bool
  default     = false
}

variable "aks_cluster_id" {
  description = "Full resource ID of the AKS cluster to monitor (required when enable_aks = true)"
  type        = string
  default     = ""
}

# --- AMPLS (Azure Monitor Private Link Scope) ---
variable "enable_ampls" {
  description = "Deploy Azure Monitor Private Link Scope for private telemetry ingestion"
  type        = bool
  default     = false
}

variable "ampls_subnet_id" {
  description = "Subnet ID for the AMPLS private endpoint (required when enable_ampls = true)"
  type        = string
  default     = ""
}

variable "ampls_vnet_id" {
  description = "VNet ID for DNS zone linking (required when enable_ampls = true)"
  type        = string
  default     = ""
}

variable "ampls_ingestion_access_mode" {
  description = "AMPLS ingestion access: Open (public + private) or PrivateOnly (zero-trust)"
  type        = string
  default     = "Open"
}

variable "ampls_query_access_mode" {
  description = "AMPLS query access: Open (public + private) or PrivateOnly (zero-trust)"
  type        = string
  default     = "Open"
}

variable "ampls_create_dns_zones" {
  description = "Create private DNS zones for AMPLS (false if managed externally)"
  type        = bool
  default     = true
}

# --- Lighthouse ---
variable "lighthouse_hub_tenant_id" {
  description = "Hub tenant ID for Lighthouse delegation"
  type        = string
  default     = ""
}

variable "lighthouse_hub_principal_id" {
  description = "Hub service principal ID for Lighthouse"
  type        = string
  default     = ""
}

# --- IoT Hub ---
variable "iot_hub_sku" {
  description = "IoT Hub SKU"
  type        = string
  default     = "S1"
}

variable "iot_hub_capacity" {
  description = "IoT Hub unit count"
  type        = number
  default     = 1
}

# --- Application Insights ---
variable "app_insights_apps" {
  description = "List of application names to create App Insights instances for"
  type        = list(string)
  default     = []
}

# --- Alert Rules ---
variable "alert_email_recipients" {
  description = "Email addresses for alert notifications"
  type        = list(string)
  default     = []
}

variable "alert_thresholds" {
  description = "Tunable thresholds for core alert rules"
  type = object({
    disk_free_percent         = optional(number, 10)
    memory_committed_percent  = optional(number, 90)
    app_exception_count       = optional(number, 50)
    cpu_anomaly_score         = optional(number, 2.0)
    heartbeat_missing_minutes = optional(number, 5)
  })
  default = {}
}

variable "servicenow_webhook_uri" {
  description = "ServiceNow webhook URI for ITSMC incident creation"
  type        = string
  default     = ""
  sensitive   = true
}

# --- Network Observability ---
variable "nsg_ids" {
  description = "Map of NSG name to resource ID for flow log creation"
  type        = map(string)
  default     = {}
}

variable "flow_log_retention_days" {
  description = "Number of days to retain NSG flow logs"
  type        = number
  default     = 90
}

# --- Workbooks ---
variable "enable_workbooks" {
  description = "Deploy auto-generated Azure Workbooks from discovery output"
  type        = bool
  default     = false
}

variable "workbook_files" {
  description = "Map of workbook display name to local JSON file path (populated by discovery/generate_workbooks.py)"
  type        = map(string)
  default     = {}
}

# --- Diagnostic Settings (populated by accelerator.py from discovery) ---
variable "diagnostic_resource_ids" {
  description = "Map of resource display name to ARM resource ID for diagnostic settings"
  type        = map(string)
  default     = {}
}

variable "diagnostic_log_categories" {
  description = "Map of resource display name to list of log categories to collect"
  type        = map(list(string))
  default     = {}
}

# --- Tags ---
variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
