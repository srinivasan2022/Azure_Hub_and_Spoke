# Create a resource group
resource "azurerm_resource_group" "Spoke_03" {
  for_each = var.rg_details
  name     = each.value.rg_name
  location = each.value.rg_location
}
 
# # Create an App Service Plan
# resource "azurerm_app_service_plan" "app_plan" {
#   name                = "app_service_plan"
#   location            = azurerm_resource_group.Spoke_03["Spoke_03_RG"].location
#   resource_group_name = azurerm_resource_group.Spoke_03["Spoke_03_RG"].name
#   sku {
#     tier = "Basic"
#     size = "B1"
#   }
#   depends_on = [ azurerm_resource_group.Spoke_03 ]
# }
 
# # Create a Web App
# resource "azurerm_app_service" "web_app" {
#   name                = "hfdkskmsktr"
#   location            = azurerm_resource_group.Spoke_03["Spoke_03_RG"].location
#   resource_group_name = azurerm_resource_group.Spoke_03["Spoke_03_RG"].name
#   app_service_plan_id = azurerm_app_service_plan.app_plan.id
 
#   site_config {
#     always_on = true
#   }
 
#   app_settings = {
#     "WEBSITE_RUN_FROM_PACKAGE" = "1"
#   }
#   depends_on = [ azurerm_app_service_plan.app_plan ]
# }

# Create an App Service Plan
resource "azurerm_app_service_plan" "example" {
  name                = "example-appserviceplan"
  location            = azurerm_resource_group.Spoke_03["Spoke_03_RG"].location
  resource_group_name = azurerm_resource_group.Spoke_03["Spoke_03_RG"].name
  sku {
    tier = "Standard"
    size = "S1"
  }
}

# Create the Web App
resource "azurerm_app_service" "example" {
  name                = "my-webapp1603"
  location            = azurerm_resource_group.Spoke_03["Spoke_03_RG"].location
  resource_group_name = azurerm_resource_group.Spoke_03["Spoke_03_RG"].name
  app_service_plan_id = azurerm_app_service_plan.example.id

  site_config {
    dotnet_framework_version = "v4.0"
  }

  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
  }

  identity {
    type = "SystemAssigned"
  }
}