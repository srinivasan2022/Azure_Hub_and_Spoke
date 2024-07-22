# Create a resource group
resource "azurerm_resource_group" "Spoke_03" {
  for_each = var.rg_details
  name     = each.value.rg_name
  location = each.value.rg_location
}

# Create the Virtual Network with address space
resource "azurerm_virtual_network" "Spoke_03_vnet" {
    for_each = var.vnet_details
    name = each.value.vnet_name
    address_space = [each.value.address_space]
    resource_group_name = azurerm_resource_group.Spoke_03["Spoke_03_RG"].name
    location = azurerm_resource_group.Spoke_03["Spoke_03_RG"].location
    depends_on = [ azurerm_resource_group.Spoke_03 ]
}

# Create the Subnets with address prefixes
resource "azurerm_subnet" "subnets" {
  for_each = var.subnet_details
  name = each.key
  address_prefixes = [each.value.address_prefix]
  virtual_network_name = azurerm_virtual_network.Spoke_03_vnet["Spoke_03_vnet"].name
  resource_group_name = azurerm_resource_group.Spoke_03["Spoke_03_RG"].name
  delegation {
    name = "appservice_delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }
  depends_on = [ azurerm_virtual_network.Spoke_03_vnet ]
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
  depends_on = [ azurerm_resource_group.Spoke_03 , azurerm_app_service_plan.plan ]
}

# Enable the Virtual Network Integration to App services
resource "azurerm_app_service_virtual_network_swift_connection" "vnet_integration" {
  app_service_id = azurerm_app_service.web_app.id
  subnet_id = azurerm_subnet.subnets["AppServiceSubnet"].id
  depends_on = [ azurerm_app_service.web_app , azurerm_subnet.subnets ]
}

# Fetch the data from Hub Virtual Network for peering the Spoke_03 Virtual Network (Spoke_03 <--> Hub)
data "azurerm_virtual_network" "Hub_vnet" {
  name = "Hub_vnet"
  resource_group_name = "Hub_RG"
}

# Establish the Peering between Spoke_01 and Hub networks (Spoke_03 <--> Hub)
resource "azurerm_virtual_network_peering" "Spoke_03-To-Hub" {
  name                      = "Spoke_03-To-Hub"
  resource_group_name       = azurerm_virtual_network.Spoke_03_vnet["Spoke_03_vnet"].resource_group_name
  virtual_network_name      = azurerm_virtual_network.Spoke_03_vnet["Spoke_03_vnet"].name
  remote_virtual_network_id = data.azurerm_virtual_network.Hub_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.Spoke_03_vnet , data.azurerm_virtual_network.Hub_vnet  ]
}

# Establish the Peering between and Hub Spoke_01 networks (Hub <--> Spoke_03)
resource "azurerm_virtual_network_peering" "Hub-Spoke_03" {
  name                      = "Hub-Spoke_03"
  resource_group_name       = data.azurerm_virtual_network.Hub_vnet.resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.Hub_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.Spoke_03_vnet["Spoke_03_vnet"].id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.Spoke_03_vnet , data.azurerm_virtual_network.Hub_vnet ]
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
