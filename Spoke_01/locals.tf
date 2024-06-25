locals {
    rules_csv = csvdecode(file(var.rules_file))

    subnet_names = [for subnet in azurerm_subnet.subnets : subnet.name]
    nsg_count = length(local.subnet_names)
    nsg_names = { for idx , nsg in azurerm_network_security_group.nsg : idx => nsg.name}

    NIC_names =  { for idx , nic in azurerm_network_interface.subnet_nic : idx => nic.name }

}