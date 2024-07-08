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

# Fetch the Subnet details from Hub Network
data "azurerm_subnet" "appService_subnet" {
  name = "AppServiceSubnet"
  resource_group_name = "Hub_RG"
  virtual_network_name = "Hub_vnet"
  
}

# Enable the Virtual Network Integration to App services
resource "azurerm_app_service_virtual_network_swift_connection" "example" {
  app_service_id = azurerm_app_service.web_app.id
  subnet_id = data.azurerm_subnet.appService_subnet.id
  depends_on = [ azurerm_app_service.web_app , data.azurerm_subnet.appService_subnet ]
}

# # Creates the policy definition
# resource "azurerm_policy_definition" "rg_policy_def" {
#   name         = "Spoke03_rg-policy"
#   policy_type  = "Custom"
#   mode         = "All"
#   display_name = "Spoke03 Policy"
#   description  = "A policy to demonstrate resource group level policy."
 
#   policy_rule = <<POLICY_RULE
#   {
#     "if": {
#       "field": "location",
#       "equals": "East US"
#     },
#     "then": {
#       "effect": "deny"
#     }
#   }
#   POLICY_RULE
 
#   metadata = <<METADATA
#   {
#     "category": "General"
#   }
#   METADATA
# }
 
# # Assign the policy
# resource "azurerm_policy_assignment" "example" {
#   name                 = "Spoke03-rg-policy-assignment"
#   policy_definition_id = azurerm_policy_definition.rg_policy_def.id
#   scope                = azurerm_resource_group.Spoke_01["Spoke_03_RG"].id
#   display_name         = "Spoke03_RG Policy Assignment"
#   description          = "Assigning policy to the resource group"
# }
