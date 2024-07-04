# Create the Resource Group
resource "azurerm_resource_group" "Hub" {
   for_each = var.rg_details
   name     = each.value.rg_name
   location = each.value.rg_location 
}

# Create the Virtual Network with address space
resource "azurerm_virtual_network" "Hub_vnet" {
    for_each = var.vnet_details
    name = each.value.vnet_name
    address_space = [each.value.address_space]
    resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
    location = azurerm_resource_group.Hub["Hub_RG"].location
    depends_on = [ azurerm_resource_group.Hub ]
}

# Create the Subnets with address prefixes
resource "azurerm_subnet" "subnets" {
  for_each = var.subnet_details
  name = each.key
  address_prefixes = [each.value.address_prefix]
  virtual_network_name = azurerm_virtual_network.Hub_vnet["Hub_vnet"].name
  resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
  depends_on = [ azurerm_virtual_network.Hub_vnet ]
}

# Creates the individual subnet for virtual network integration to connect the App services
resource "azurerm_subnet" "AppServiceSubnet" {
  for_each = var.appService_subnet
  name = each.key
  address_prefixes = [each.value.address_prefix]
  virtual_network_name = azurerm_virtual_network.Hub_vnet["Hub_vnet"].name
  resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
  delegation {
    name = "appservice_delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }
  depends_on = [ azurerm_virtual_network.Hub_vnet ]
}


# Create the Public IP's for Azure Firewall , VPN Gateway and Azure Bastion Host 
resource "azurerm_public_ip" "public_ips" {
  for_each = toset(local.subnet_names)
  name = "${each.key}-IP"
  location            = azurerm_resource_group.Hub["Hub_RG"].location
  resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on = [ azurerm_resource_group.Hub ]
}

# # Create the Azure Bastion Host
# resource "azurerm_bastion_host" "bastion" {
#   name                = "Bastion"
#   location            = azurerm_resource_group.Hub["Hub_RG"].location
#   resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
#   sku = "Basic"
#   ip_configuration {
#     public_ip_address_id = azurerm_public_ip.public_ips["AzureBastionSubnet"].id
#     name = "example"
#     subnet_id = azurerm_subnet.subnets["AzureBastionSubnet"].id
#   }
#   depends_on = [ azurerm_resource_group.Hub , azurerm_public_ip.public_ips , azurerm_subnet.subnets ]
# }

resource "azurerm_firewall_policy" "firewall_policy" {
  name                = "example-firewall-policy"
  location            = azurerm_resource_group.Hub["Hub_RG"].location
  resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
  sku = "Standard"
  depends_on = [ azurerm_resource_group.Hub , azurerm_subnet.subnets ]
}
 
# Create the Azure Firewall in their Specified Subnet
resource "azurerm_firewall" "firewall" {
  name                = "Firewall"
  location            = azurerm_resource_group.Hub["Hub_RG"].location
  resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
   sku_name = "AZFW_VNet"
   sku_tier = "Standard"

  ip_configuration {
    name                 = "firewallconfiguration"
    subnet_id            = azurerm_subnet.subnets["AzureFirewallSubnet"].id
    public_ip_address_id = azurerm_public_ip.public_ips["AzureFirewallSubnet"].id
  }
   firewall_policy_id = azurerm_firewall_policy.firewall_policy.id
  depends_on = [ azurerm_resource_group.Hub , azurerm_public_ip.public_ips , 
  azurerm_subnet.subnets , azurerm_firewall_policy.firewall_policy ]
}

# resource "azurerm_firewall_policy_rule_collection_group" "example" {
#   name                = "example-rule-collection-group"
#   firewall_policy_id  = azurerm_firewall_policy.example.id
#   priority            = 100
 
#   network_rule_collection {
#     name     = "network-rule-collection"
#     priority = 200
#     action   = "Allow"
 
#     rule {
#       name                  = "allow-dns"
#       description           = "Allow DNS"
#       rule_type             = "NetworkRule"
#       source_addresses      = ["*"]
#       destination_addresses = ["*"]
#       destination_ports     = ["53"]
#       protocols             = ["UDP", "TCP"]
#     }
#   }
 
#   application_rule_collection {
#     name     = "application-rule-collection"
#     priority = 300
#     action   = "Allow"
 
#     rule {
#       name             = "allow-web"
#       description      = "Allow Web Access"
#       source_addresses = ["*"]
#       protocols {
#         type = "Http"
#         port = 80
#       }
#       protocols {
#         type = "Https"
#         port = 443
#       }
#       target_fqdns = ["*"]
#     }
#   }
# }
 

# # Create the VPN Gateway in their Specified Subnet
# resource "azurerm_virtual_network_gateway" "gateway" {
#   name                = "Hub-vpn-gateway"
#   location            = azurerm_resource_group.Hub["Hub_RG"].location
#   resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
 
#   type     = "Vpn"
#   vpn_type = "RouteBased"
#   active_active = false
#   enable_bgp    = false
#   sku           = "VpnGw1"
 
#   ip_configuration {
#     name                = "vnetGatewayConfig"
#     public_ip_address_id = azurerm_public_ip.public_ips["GatewaySubnet"].id
#     private_ip_address_allocation = "Dynamic"
#     subnet_id = azurerm_subnet.subnets["GatewaySubnet"].id
#   }
#   depends_on = [ azurerm_resource_group.Hub , azurerm_public_ip.public_ips , azurerm_subnet.subnets ]
# }

# # Fetch the data from On_premises Gateway Public_IP (IP_address)
# data "azurerm_public_ip" "OnPrem-VPN-GW-public-ip" {
#   name = "OnPremise-VPN-GatewaySubnet-IP"
#   resource_group_name = "On_Premises_RG"
# }

# # Fetch the data from On_Premise Virtual Network (address_space)
# data "azurerm_virtual_network" "On_Premises_vnet" {
#   name = "On_Premises_vnet"
#   resource_group_name = "On_Premises_RG"
# }


# # Create the Local Network Gateway for VPN Gateway
# resource "azurerm_local_network_gateway" "Hub_local_gateway" {
#   name                = "Hub-To-OnPremises"
#   location            = azurerm_resource_group.Hub["Hub_RG"].location
#   resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
#   gateway_address     = data.azurerm_public_ip.OnPrem-VPN-GW-public-ip.ip_address
#   address_space       = [data.azurerm_virtual_network.On_Premises_vnet.address_space[0]]
#   depends_on = [ azurerm_public_ip.public_ips , azurerm_virtual_network_gateway.gateway , 
#               data.azurerm_public_ip.OnPrem-VPN-GW-public-ip ,data.azurerm_virtual_network.On_Premises_vnet ]
# }

#  # Create the VPN-Connection for Connecting the Networks
# resource "azurerm_virtual_network_gateway_connection" "vpn_connection" {
#   name                           = "Hub-OnPremises-vpn-connection"
#   location            = azurerm_resource_group.Hub["Hub_RG"].location
#   resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
#   virtual_network_gateway_id     = azurerm_virtual_network_gateway.gateway.id
#   local_network_gateway_id       = azurerm_local_network_gateway.Hub_local_gateway.id
#   type                           = "IPsec"
#   connection_protocol            = "IKEv2"
#   shared_key                     = "YourSharedKey"

#   depends_on = [ azurerm_virtual_network_gateway.gateway , azurerm_local_network_gateway.Hub_local_gateway]
# }





