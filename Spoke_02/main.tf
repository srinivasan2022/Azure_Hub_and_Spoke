# Create the Resource Group
resource "azurerm_resource_group" "Spoke_02" {
   for_each = var.rg_details
   name     = each.value.rg_name
   location = each.value.rg_location
}

# Create the Virtual Network with address space
resource "azurerm_virtual_network" "Spoke_02_vnet" {
    for_each = var.vnet_details
    name = each.value.vnet_name
    address_space = [each.value.address_space]
    resource_group_name = azurerm_resource_group.Spoke_02["Spoke_02_RG"].name
    location = azurerm_resource_group.Spoke_02["Spoke_02_RG"].location
    depends_on = [ azurerm_resource_group.Spoke_02 ]
}

# Create the Subnets with address prefixes
resource "azurerm_subnet" "subnets" {
  for_each = var.subnet_details
  name = each.key
  address_prefixes = [each.value.address_prefix]
  virtual_network_name = azurerm_virtual_network.Spoke_02_vnet["Spoke_02_vnet"].name
  resource_group_name = azurerm_resource_group.Spoke_02["Spoke_02_RG"].name
  depends_on = [ azurerm_virtual_network.Spoke_02_vnet ]
}

# Create the Network Security Group with Rules
resource "azurerm_network_security_group" "nsg" {
  for_each = toset(local.subnet_names)
  name = each.key
  resource_group_name = azurerm_resource_group.Spoke_02["Spoke_02_RG"].name
  location = azurerm_resource_group.Spoke_02["Spoke_02_RG"].location

  dynamic "security_rule" {                           
     for_each = { for rule in local.rules_csv : rule.name => rule }
     content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }
  depends_on = [ azurerm_subnet.subnets ]
  
}

# Associate the NSG for their Subnets
# resource "azurerm_subnet_network_security_group_association" "nsg_ass" {
#   for_each = { for idx , subnet in azurerm_subnet.subnets : idx => subnet.id}
#   subnet_id                 = each.value
#   network_security_group_id =   azurerm_network_security_group.nsg[local.nsg_names[each.key]].id
#   depends_on = [ azurerm_network_security_group.nsg ]
# }

# Create the Public IP for Application Gateway
resource "azurerm_public_ip" "public_ip" {
  name                = "AppGW-Pub-IP"
  resource_group_name = azurerm_resource_group.Spoke_02["Spoke_02_RG"].name
  location = azurerm_resource_group.Spoke_02["Spoke_02_RG"].location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create the Application for their dedicated subnet
resource "azurerm_application_gateway" "appGW" {
  name                = "App-Gateway"
  resource_group_name = azurerm_resource_group.Spoke_02["Spoke_02_RG"].name
  location = azurerm_resource_group.Spoke_02["Spoke_02_RG"].location
  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.subnets["App-GW"].id
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }

  frontend_port {
    name = "frontend-port"
    port = 80
  }

  backend_address_pool {
    name = "appgw-backend-pool"
  }

  backend_http_settings {
    name                  = "appgw-backend-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }

  http_listener {
    name                           = "appgw-http-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "frontend-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "appgw-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "appgw-http-listener"
    backend_address_pool_name  = "appgw-backend-pool"
    backend_http_settings_name = "appgw-backend-http-settings"
  }
    depends_on = [azurerm_resource_group.Spoke_02 ,azurerm_subnet.subnets ,azurerm_public_ip.public_ip]
 }

## Create windows Virtual Machine Scale Set (VMSS)
resource "azurerm_windows_virtual_machine_scale_set" "vmss" {
  name                = "myvmss"
  resource_group_name = azurerm_resource_group.Spoke_02["Spoke_02_RG"].name
  location = azurerm_resource_group.Spoke_02["Spoke_02_RG"].location
  sku = "Standard_DS1_v2"
  instances = 2
  admin_username = "asdd"
  admin_password = "pass@word1234"

  # sku {
  #   name     = "Standard_DS1_v2"
  #   tier     = "Standard"
  #   capacity = 2
  # }
  network_interface {
    name = "myvmss"
    primary = true
    ip_configuration {
      name = "internal"
      subnet_id = azurerm_subnet.subnets["VMSS"].id
      //load_balancer_backend_address_pool_ids =
      application_gateway_backend_address_pool_ids = [local.application_gateway_backend_address_pool_ids[0]]
    }
  }
  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  # network_profile {
  #   name    = "my-vmss-nic"
  #   primary = true
  #   ip_configuration {
  #     name                                   = "internal"
  #     subnet_id                              = azurerm_subnet.subnets["VMSS"].id
  #     primary                                = true
  #     load_balancer_backend_address_pool_ids = [azurerm_application_gateway.appGW.id]
  #   }                                       //[azurerm_application_gateway.example.backend_address_pool[0].id]
  # }

  # storage_profile_image_reference {
  #   publisher = "MicrosoftWindowsServer"
  #   offer     = "WindowsServer"
  #   sku       = "2019-Datacenter"
  #   version   = "latest"
  # }

  # storage_profile_os_disk {
  #   caching           = "ReadWrite"
  #   create_option     = "FromImage"
  #   managed_disk_type = "Standard_LRS"
  # }

  # os_profile {
  #   computer_name_prefix = "examplevmss"
  #   admin_username       = "adminuser"
  #   admin_password       = "Password1234!"
  # }

  # os_profile_windows_config {
  #    provision_vm_agent = true
  # }

  depends_on = [azurerm_application_gateway.appGW , azurerm_subnet.subnets]
}


# # Fetch the data from Hub Virtual Network for peering the Spoke_02 Virtual Network (Spoke_02 <--> Hub)
# data "azurerm_virtual_network" "Hub_vnet" {
#   name = "Hub_vnet"
#   resource_group_name = "Hub_RG"
# }

# # Establish the Peering between Spoke_02 and Hub networks (Spoke_02 <--> Hub)
# resource "azurerm_virtual_network_peering" "Spoke_02-To-Hub" {
#   name                      = "Spoke_02-To-Hub"
#   resource_group_name       = azurerm_virtual_network.Spoke_02_vnet["Spoke_02_vnet"].resource_group_name
#   virtual_network_name      = azurerm_virtual_network.Spoke_02_vnet["Spoke_02_vnet"].name
#   remote_virtual_network_id = data.azurerm_virtual_network.Hub_vnet.id
#   allow_virtual_network_access = true
#   allow_forwarded_traffic   = true
#   allow_gateway_transit     = false
#   use_remote_gateways       = false
#   depends_on = [ azurerm_virtual_network.Spoke_02_vnet , data.azurerm_virtual_network.Hub_vnet  ]
# }

# # Establish the Peering between and Hub Spoke_01 networks (Hub <--> Spoke_02)
# resource "azurerm_virtual_network_peering" "Hub-Spoke_02" {
#   name                      = "Hub-Spoke_02"
#   resource_group_name       = data.azurerm_virtual_network.Hub_vnet.resource_group_name
#   virtual_network_name      = data.azurerm_virtual_network.Hub_vnet.name
#   remote_virtual_network_id = azurerm_virtual_network.Spoke_02_vnet["Spoke_02_vnet"].id
#   allow_virtual_network_access = true
#   allow_forwarded_traffic   = true
#   allow_gateway_transit     = false
#   use_remote_gateways       = false
#   depends_on = [ azurerm_virtual_network.Spoke_02_vnet , data.azurerm_virtual_network.Hub_vnet ]
# }