variable "rg_details" {
  type = map(object({
    rg_name = string
    rg_location = string
  }))
  default = {
    "Spoke_03_RG" = {
      rg_name = "Spoke_03_RG"
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
    "Spoke_03_vnet" = {
      vnet_name = "Spoke_03_vnet"
      address_space = "10.40.0.0/16"
    }
  }
}
variable "subnet_details" {
  type = map(object({
    subnet_name = string
    address_prefix = string
  }))
  default = {
    "AppServiceSubnet" = {
      subnet_name = "AppServiceSubnet"
      address_prefix = "10.40.0.0/27"
    }
 }
}