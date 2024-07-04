output "Hub_RG" {
  value = azurerm_resource_group.Hub
}

output "Hub_vnet_" {
  value = azurerm_virtual_network.Hub_vnet
}

output "Subnet_details" {
  value = azurerm_subnet.subnets
}

# output "Public_ips" {
#  value = azurerm_public_ip.public_ips
# }

# output "Bastion" {
#  value = azurerm_bastion_host.bastion
# }

# output "Firewall" {
#  value = azurerm_firewall.firewall
# }

# output "VPN_Gateway" {
#  value = azurerm_virtual_network_gateway.gateway
# }