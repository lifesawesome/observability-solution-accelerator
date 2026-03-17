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

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
