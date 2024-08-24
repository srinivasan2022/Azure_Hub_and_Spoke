locals {
    rules_csv = csvdecode(file(var.rules_file))
    subnet_names = [for subnet in azurerm_subnet.subnets : subnet.name]
    application_gateway_backend_address_pool_ids = [for pool in azurerm_application_gateway.appGW.backend_address_pool : pool.id]

}