variable "workbook_files" {
  description = "Map of workbook display name to the local file path of the workbook JSON definition."
  type        = map(string)
}

variable "resource_group_name" {
  description = "Name of the Azure resource group where workbooks will be deployed."
  type        = string
}

variable "location" {
  description = "Azure region for the workbook resources."
  type        = string
}

variable "workspace_id" {
  description = "Resource ID of the Log Analytics workspace to associate workbooks with."
  type        = string
}

variable "tags" {
  description = "Tags to apply to all workbook resources."
  type        = map(string)
  default     = {}
}
