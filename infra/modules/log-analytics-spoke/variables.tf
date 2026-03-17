variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "workspace_name" {
  description = "Log Analytics Workspace name"
  type        = string
}

variable "sku" {
  description = "Workspace SKU: PerGB2018 or CapacityReservation"
  type        = string
  default     = "PerGB2018"
}

variable "capacity_reservation_level" {
  description = "Capacity reservation GB/day (only for CapacityReservation SKU)"
  type        = number
  default     = 100
}

variable "retention_in_days" {
  description = "Interactive data retention in days"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
