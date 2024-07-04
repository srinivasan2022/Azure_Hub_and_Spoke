variable "rg_details" {
  type = map(object({
    rg_name = string
    rg_location = string
  }))
  default = {
    "On_Premises_RG" = {
      rg_name = "On_Premises_RG"
      rg_location = "central india"
    }
  }
}

variable "vnet_details" {
  type = map(object({
    vnet_name = string
    address_space = string
  }))
  default = {
    "On_Premises_vnet" = {
      vnet_name = "On_Premises_vnet"
      address_space = "10.100.0.0/16"
    }
  }
}

variable "subnet_details" {
  type = map(object({
    subnet_name = string
    address_prefix = string
  }))
  default = {
    "GatewaySubnet" = {
      subnet_name = "GatewaySubnet"
      address_prefix = "10.100.1.0/24"
    },
    
    "DB" = {
        subnet_name = "DB"
        address_prefix = "10.100.2.0/24"
    }
  }
}


variable "admin_username" {
  type        = string
  default = "azureuser"
}

variable "admin_password" {
  type        = string
  default = "pass@word1234"
  sensitive   = true
}