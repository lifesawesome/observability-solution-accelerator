variable "workspace_id" {
  description = "Log Analytics Workspace ID"
  type        = string
}

variable "dcr_windows_id" {
  description = "Windows Data Collection Rule ID"
  type        = string
}

variable "dcr_linux_id" {
  description = "Linux Data Collection Rule ID"
  type        = string
}

variable "customer_name" {
  description = "Customer name for policy naming"
  type        = string
}
