variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "iot_hub_name" {
  description = "IoT Hub name"
  type        = string
}

variable "sku" {
  description = "IoT Hub SKU (S1, S2, S3)"
  type        = string
  default     = "S1"
}

variable "capacity" {
  description = "IoT Hub unit count"
  type        = number
  default     = 1
}

variable "partition_count" {
  description = "Event Hub partition count"
  type        = number
  default     = 4
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
