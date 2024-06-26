locals {
     subnet_names = [for subnet in azurerm_subnet.subnets : subnet.name]
}