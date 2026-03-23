variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "workspace_id" {
  description = "Log Analytics Workspace ID for Traffic Analytics"
  type        = string
}

variable "workspace_customer_id" {
  description = "Log Analytics Workspace customer/GUID ID for Traffic Analytics"
  type        = string
}

variable "customer_name" {
  description = "Customer name for naming"
  type        = string
}

variable "nsg_ids" {
  description = "Map of NSG name to resource ID for flow log creation. Example: { 'nsg-web' = '/subscriptions/.../nsg-web' }"
  type        = map(string)
  default     = {}
}

variable "flow_log_retention_days" {
  description = "Number of days to retain NSG flow logs"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
