variable "rg_details" {
  type = map(object({
    rg_name = string
    rg_location = string
  }))
  default = {
    "Spoke_01_RG" = {
      rg_name = "Spoke_01_RG"
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
    "Spoke_01_vnet" = {
      vnet_name = "Spoke_01_vnet"
      address_space = "10.20.0.0/16"
    }
  }
}

variable "subnet_details" {
  type = map(object({
    subnet_name = string
    address_prefix = string
  }))
  default = {
    "Web-01" = {
      subnet_name = "Web-01"
      address_prefix = "10.20.1.0/24"
    },
    
    "Web-02" = {
        subnet_name = "Web-02"
        address_prefix = "10.20.2.0/24"
    }
  }
}

variable "rules_file" {
    type = string
    default = "rules.csv"
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
