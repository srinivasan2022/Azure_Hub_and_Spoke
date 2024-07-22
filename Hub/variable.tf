variable "rg_details" {
  type = map(object({
    rg_name = string
    rg_location = string
  }))
  default = {
    "Hub_RG" = {
      rg_name = "Hub_RG"
      rg_location = "East us"
    }
  }
}

variable "vnet_details" {
  type = map(object({
    vnet_name = string
    address_space = string
  }))
  default = {
    "Hub_vnet" = {
      vnet_name = "Hub_vnet"
      address_space = "10.10.0.0/16"
    }
  }
}

variable "subnet_details" {
  type = map(object({
    subnet_name = string
    address_prefix = string
  }))
  default = {
    "AzureFirewallSubnet" = {
        subnet_name = "AzureFirewallSubnet"
        address_prefix = "10.10.0.0/26"
    },

    "GatewaySubnet" = {
      subnet_name = "GatewaySubnet"
      address_prefix = "10.10.1.0/27"
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
