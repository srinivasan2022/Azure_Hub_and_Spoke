output "Spoke_02_RG" {
  value = azurerm_resource_group.Spoke_02
}

output "Spoke_02_vnet" {
  value = azurerm_virtual_network.Spoke_02_vnet
}

output "subnet_details" {
  value = azurerm_subnet.subnets
}

output "public_ip" {
  value = azurerm_public_ip.public_ip
}

output "AppGW" {
  value = azurerm_application_gateway.appGW
}

