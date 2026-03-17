variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "customer_name" {
  description = "Customer name for naming"
  type        = string
}

variable "email_recipients" {
  description = "Email addresses for alert notifications"
  type        = list(string)
  default     = []
}

variable "servicenow_webhook_uri" {
  description = "ServiceNow webhook URI for incident creation"
  type        = string
  default     = ""
  sensitive   = true
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
