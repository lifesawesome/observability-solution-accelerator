variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "app_insights_name" {
  description = "Application Insights resource name"
  type        = string
}

variable "workspace_id" {
  description = "Log Analytics Workspace ID to link to"
  type        = string
}

variable "application_type" {
  description = "Application type"
  type        = string
  default     = "web"
}

variable "sampling_percentage" {
  description = "Sampling percentage (reduce for high-volume apps)"
  type        = number
  default     = 100
}

variable "retention_in_days" {
  description = "Data retention in days"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
