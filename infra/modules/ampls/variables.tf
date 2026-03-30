variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "ampls_name" {
  description = "Name for the Azure Monitor Private Link Scope"
  type        = string
}

variable "workspace_id" {
  description = "Log Analytics Workspace resource ID to scope into AMPLS"
  type        = string
}

variable "app_insights_ids" {
  description = "Map of App Insights name to resource ID to scope into AMPLS"
  type        = map(string)
  default     = {}
}

variable "subnet_id" {
  description = "Subnet ID for the AMPLS private endpoint"
  type        = string
}

variable "vnet_id" {
  description = "VNet ID for DNS zone linking (required when create_private_dns_zones = true)"
  type        = string
  default     = ""
}

variable "ingestion_access_mode" {
  description = "AMPLS ingestion access mode: Open (allow public + private) or PrivateOnly"
  type        = string
  default     = "Open"
  validation {
    condition     = contains(["Open", "PrivateOnly"], var.ingestion_access_mode)
    error_message = "Must be 'Open' or 'PrivateOnly'."
  }
}

variable "query_access_mode" {
  description = "AMPLS query access mode: Open (allow public + private) or PrivateOnly"
  type        = string
  default     = "Open"
  validation {
    condition     = contains(["Open", "PrivateOnly"], var.query_access_mode)
    error_message = "Must be 'Open' or 'PrivateOnly'."
  }
}

variable "create_private_dns_zones" {
  description = "Create private DNS zones for Azure Monitor (set false if managed externally)"
  type        = bool
  default     = true
}

variable "private_dns_zone_ids" {
  description = "Existing private DNS zone IDs (used when create_private_dns_zones = false)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
