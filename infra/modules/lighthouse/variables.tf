variable "customer_name" {
  description = "Customer name"
  type        = string
}

variable "hub_tenant_id" {
  description = "Hub MSP tenant ID"
  type        = string
}

variable "hub_principal_id" {
  description = "Hub service principal or group ID for delegation"
  type        = string
}
