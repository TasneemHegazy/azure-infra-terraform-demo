variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "germanywestcentral"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "devops-demo-rg"
}