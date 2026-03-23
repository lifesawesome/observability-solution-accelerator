variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "aks_cluster_id" {
  description = "Full resource ID of the AKS cluster to monitor"
  type        = string
}

variable "workspace_id" {
  description = "Log Analytics Workspace resource ID"
  type        = string
}

variable "action_group_id" {
  description = "Action Group ID for AKS alert notifications"
  type        = string
}

variable "customer_name" {
  description = "Customer name for resource naming"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
