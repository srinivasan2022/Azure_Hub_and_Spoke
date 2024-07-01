output "On_Premise_RG" {
  value = azurerm_resource_group.On_Premises
}

output "On_Premise_vnet_" {
  value = azurerm_virtual_network.On_Premises_vnet
}

output "Subnet_details" {
  value = azurerm_subnet.subnets
}

output "Public_ips" {
 value = azurerm_public_ip.public_ips
}

output "VPN_Gateway" {
 value = azurerm_virtual_network_gateway.gateway
}