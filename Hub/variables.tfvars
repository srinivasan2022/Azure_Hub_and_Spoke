rg_name = "Hub_RG"
rg_location = "East us"

vnet_details = {
  "Hub_vnet" = {
      vnet_name = "Hub_vnet"
      address_space = "10.10.0.0/16"
    }
}

subnet_details = {
  "AzureFirewallSubnet" = {
        subnet_name = "AzureFirewallSubnet"
        address_prefix = "10.10.0.0/26"
    },

    "GatewaySubnet" = {
      subnet_name = "GatewaySubnet"
      address_prefix = "10.10.1.0/27"
    }
}


