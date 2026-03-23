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

variable "action_group_id" {
  description = "Action Group ID for alert notifications"
  type        = string
}

variable "customer_name" {
  description = "Customer name for alert naming"
  type        = string
}

variable "alert_thresholds" {
  description = "Tunable thresholds for core alert rules. Override per-customer."
  type = object({
    disk_free_percent         = optional(number, 10)
    memory_committed_percent  = optional(number, 90)
    app_exception_count       = optional(number, 50)
    cpu_anomaly_score         = optional(number, 2.0)
    heartbeat_missing_minutes = optional(number, 5)
  })
  default = {}
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
