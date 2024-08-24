rg_name = "Spoke_03_RG"
rg_location = "East us"

vnet_details = {
  "Spoke_03_vnet" = {
      vnet_name = "Spoke_03_vnet"
      address_space = "10.40.0.0/16"
    }
}

subnet_details = {

     "VnetIntegrationSubnet" = {
      subnet_name = "VnetIntegrationSubnet"    # This Subnet is created for VnetIntegration with appservices.
      address_prefix = "10.40.0.0/27"
    } ,
    "AppServiceSubnet" = {
      subnet_name = "AppServiceSubnet"         # This Subnet is created for private endpoint.
      address_prefix = "10.40.1.0/26"
    }
}

app_service_plan_name = "appserviceplan"

web_app_name = "my-webapp1603"


