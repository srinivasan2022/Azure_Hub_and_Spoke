variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default = "Project_TF_RemoteState_RG"
}

variable "location" {
  description = "The region in which the resources will be deployed"
  type        = string
  default = "east us"
}

variable "storage_account_name" {
  description = "The name of the storage account"
  type        = string
  default = "projectremotestatestacc"
}