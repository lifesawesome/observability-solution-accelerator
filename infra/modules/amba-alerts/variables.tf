variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "workspace_id" {
  description = "Log Analytics Workspace ID (alert scope)"
  type        = string
}

variable "critical_action_group_id" {
  description = "Action Group ID for critical (P1/P2) alerts"
  type        = string
}

variable "warning_action_group_id" {
  description = "Action Group ID for warning (P3/P4) alerts"
  type        = string
}

variable "customer_name" {
  description = "Customer name for alert naming"
  type        = string
}

variable "amba_services" {
  description = "List of Azure services to enable AMBA alerts for. Options: vm, sql, appservice, aks, storage, keyvault, eventhub, cosmosdb, databricks, loadbalancer"
  type        = list(string)
  default     = ["vm"]
  validation {
    condition = alltrue([
      for s in var.amba_services : contains(
        ["vm", "sql", "appservice", "aks", "storage", "keyvault", "eventhub", "cosmosdb", "databricks", "loadbalancer"],
        s
      )
    ])
    error_message = "Each amba_services entry must be one of: vm, sql, appservice, aks, storage, keyvault, eventhub, cosmosdb, databricks, loadbalancer."
  }
}

variable "thresholds" {
  description = "Tunable thresholds for AMBA alerts. Override per-customer as needed."
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

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
