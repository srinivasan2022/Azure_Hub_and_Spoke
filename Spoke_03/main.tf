# Create a resource group
resource "azurerm_resource_group" "Spoke_03" {
  for_each = var.rg_details
  name     = each.value.rg_name
  location = each.value.rg_location
}
 
# Create an App Service Plan
resource "azurerm_app_service_plan" "plan" {
  name                = "appserviceplan"
  location            = azurerm_resource_group.Spoke_03["Spoke_03_RG"].location
  resource_group_name = azurerm_resource_group.Spoke_03["Spoke_03_RG"].name
  sku {
    tier = "Standard"
    size = "S1"
  }
  depends_on = [ azurerm_resource_group.Spoke_03 ]
}

# Create the Web App
resource "azurerm_app_service" "web_app" {
  name                = "my-webapp1603"
  location            = azurerm_resource_group.Spoke_03["Spoke_03_RG"].location
  resource_group_name = azurerm_resource_group.Spoke_03["Spoke_03_RG"].name
  app_service_plan_id = azurerm_app_service_plan.plan.id

  # site_config {
  #   dotnet_framework_version = "v4.0"
  # }

  # app_settings = {
  #   "WEBSITE_RUN_FROM_PACKAGE" = "1"
  # }

  # identity {
  #   type = "SystemAssigned"
  # }
  depends_on = [ azurerm_resource_group.Spoke_03 , azurerm_app_service_plan.plan ]
}

# Fetch the Subnet details from Spoke_01 Network
data "azurerm_subnet" "app_subnet" {
  name = "App"
  resource_group_name = "Spoke_01_RG"
  virtual_network_name = "Spoke_01_vnet"
}

# Enable the Virtual Network Integration to App services
resource "azurerm_app_service_virtual_network_swift_connection" "example" {
  app_service_id = azurerm_app_service.web_app.id
  subnet_id = data.azurerm_subnet.app_subnet.id
  depends_on = [ azurerm_app_service.web_app , data.azurerm_subnet.app_subnet ]
}