rg_name = "Spoke_02_RG"
rg_location = "East us"

vnet_details = {
  "Spoke_02_vnet" = {
      vnet_name = "Spoke_02_vnet"
      address_space = "10.30.0.0/16"
    }
}

subnet_details = {
 "App-GW" = {
      subnet_name = "App-GW"
      address_prefix = "10.30.1.0/24"
    },
    
    "VMSS" = {
        subnet_name = "VMSS"
        address_prefix = "10.30.2.0/24"
    }
}
