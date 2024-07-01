locals {
    rules_csv = csvdecode(file(var.rules_file))
    subnet_names = [for subnet in azurerm_subnet.subnets : subnet.name]
    nsg_count = length(local.subnet_names)
    nsg_names = { for idx , nsg in azurerm_network_security_group.nsg : idx => nsg.name}

    application_gateway_backend_address_pool_ids = [for pool in azurerm_application_gateway.appGW.backend_address_pool : pool.id]

}