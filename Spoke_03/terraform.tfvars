rg_name = "Spoke_03_RG"
rg_location = "East us"

vnet_details = {
  "Spoke_03_vnet" = {
      vnet_name = "Spoke_03_vnet"
      address_space = "10.40.0.0/16"
    }
}

subnet_details = {
    "AppServiceSubnet" = {
      subnet_name = "AppServiceSubnet"
      address_prefix = "10.40.0.0/27"
    }
}

app_service_plan_name = "appserviceplan"
web_app_name = "my-webapp1603"

