locals {
    subnet_names = [for subnet in azurerm_subnet.subnets : subnet.name]

     NIC_names =  { for idx , nic in azurerm_network_interface.subnet_nic : idx => nic.name }

}