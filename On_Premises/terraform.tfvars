rg_name = "On_Premises_RG"
rg_location = "central india"

vnet_details = {
  "On_Premises_vnet" = {
      vnet_name = "On_Premises_vnet"
      address_space = "10.100.0.0/16"
    }
}

subnet_details = {
  "GatewaySubnet" = {
      subnet_name = "GatewaySubnet"
      address_prefix = "10.100.1.0/24"
    },
    
    "OnPremSubnet" = {
        subnet_name = "OnPremSubnet"
        address_prefix = "10.100.2.0/24"
    }
}

Key_vault_name = "MyKeyVault160320"
admin_username = "azureuser"
admin_password = "pass@word1234"