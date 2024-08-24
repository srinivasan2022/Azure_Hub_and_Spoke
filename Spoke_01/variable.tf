variable "rg_name" {
  type = string
  description = "The name of the Resource Group"
  validation {
    condition = length(var.rg_name)>0
    error_message = "The name must be provided"
  }

}

variable "rg_location" {
  type = string
  description = "The Location of the Resource Group"
  validation {
    condition = length(var.rg_location)>0
    error_message = "The Location must be provided"
  }
}

variable "vnet_details" {
  type = map(object({
    vnet_name = string
    address_space = string
  }))
  description = "The details of the VNET"
}

variable "subnet_details" {
  type = map(object({
    subnet_name = string
    address_prefix = string
  }))
  description = "The details of the Subnets"
}

variable "rules_file" {
  type = string
  description = "The name of CSV file containing NSG rules"
  default = "rules.csv"
}
variable "storage_account_name" {
  type = string
  description = "The name of storage account name"
}

variable "file_share_name" {
  type = string
  description = "The name of file share name"
}


variable "data_disk_name" {
  type = string
  description = "The name of Data disk name"
}




