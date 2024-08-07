rg_name = "Spoke_01_RG"
rg_location = "East us"

vnet_details = {
  "Spoke_01_vnet" = {
      vnet_name = "Spoke_01_vnet"
      address_space = "10.20.0.0/16"
    }
}

subnet_details = {
   "Web-01" = {
      subnet_name = "Web-01"
      address_prefix = "10.20.1.0/24"
    },
    
    "Web-02" = {
        subnet_name = "Web-02"
        address_prefix = "10.20.2.0/24"
    }
}

storage_account_name = "storageaccount160302"
file_share_name = "fileshare01"
data_disk_name = "vm-datadisk"
