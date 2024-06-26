output "Spoke_01_RG" {
  value = azurerm_resource_group.Spoke_01
}

output "Spoke_01_vnet" {
  value = azurerm_virtual_network.Spoke_01_vnet
}

output "subnet_details" {
  value = azurerm_subnet.subnets
}

# output "VMs" {
#   value = azurerm_windows_virtual_machine.VMs
# }

