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

# Create the Public IP's for Azure Firewall , VPN Gateway and Azure Bastion Host 
resource "azurerm_public_ip" "public_ips" {
  for_each = toset(local.subnet_names)
  name = each.key
  location            = azurerm_resource_group.Hub["Hub_RG"].location
  resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on = [ azurerm_resource_group.Hub ]
}

# Create the Azure Bastion Host
resource "azurerm_bastion_host" "bastion" {
  name                = "Bastion"
  location            = azurerm_resource_group.Hub["Hub_RG"].location
  resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
  sku = "Basic"
  ip_configuration {
    public_ip_address_id = azurerm_public_ip.public_ips["AzureBastionSubnet"].id
    name = "example"
    subnet_id = azurerm_subnet.subnets["AzureBastionSubnet"].id
  }
  depends_on = [ azurerm_resource_group.Hub , azurerm_public_ip.public_ips , azurerm_subnet.subnets ]
}

# Create the Azure Firewall in their Specified Subnet
# resource "azurerm_firewall" "firewall" {
#   name                = "Firewall"
#   location            = azurerm_resource_group.Hub["Hub_RG"].location
#   resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
#    sku_name = "AZFW_VNet"
#    sku_tier = "Standard"

#   ip_configuration {
#     name                 = "firewallconfiguration"
#     subnet_id            = azurerm_subnet.subnets["AzureFirewallSubnet"].id
#     public_ip_address_id = azurerm_public_ip.public_ips["AzureFirewallSubnet"].id
#   }

#   depends_on = [ azurerm_resource_group.Hub , azurerm_public_ip.public_ips , azurerm_subnet.subnets]
# }

# Create the VPN Gateway in their Specified Subnet
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

# Create the Local Network Gateway for VPN Gateway
# resource "azurerm_local_network_gateway" "Hub_local_gateway" {
#   name                = "Hub-To-OnPremises"
#   location            = azurerm_resource_group.Hub["Hub_RG"].location
#   resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
#   gateway_address     = "YOUR_ON_PREMISES_VPN_PUBLIC_IP"
#   address_space       = ["YOUR_ON_PREMISES_ADDRESS_SPACE"]
#   depends_on = [ azurerm_public_ip.public_ips , azurerm_virtual_network_gateway.gateway ]
# }

# Create the VPN-Connection for Connecting the Networks
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


