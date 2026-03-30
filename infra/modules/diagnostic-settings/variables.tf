variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "workspace_id" {
  description = "Log Analytics Workspace resource ID to send diagnostics to"
  type        = string
}

variable "customer_name" {
  description = "Customer name for naming diagnostic settings"
  type        = string
}

variable "resource_ids" {
  description = "Map of resource display name to full ARM resource ID"
  type        = map(string)
  default     = {}
}

variable "log_categories_per_resource" {
  description = "Map of resource display name to list of log categories to enable"
  type        = map(list(string))
  default     = {}
}
