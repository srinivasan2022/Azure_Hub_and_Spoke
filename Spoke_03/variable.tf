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