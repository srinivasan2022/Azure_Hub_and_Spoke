data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}

# Create the Resource Group
resource "azurerm_resource_group" "Spoke_01" {
   for_each = var.rg_details
   name     = each.value.rg_name
   location = each.value.rg_location
}

# Create the Virtual Network with address space
resource "azurerm_virtual_network" "Spoke_01_vnet" {
    for_each = var.vnet_details
    name = each.value.vnet_name
    address_space = [each.value.address_space]
    resource_group_name = azurerm_resource_group.Spoke_01["Spoke_01_RG"].name
    location = azurerm_resource_group.Spoke_01["Spoke_01_RG"].location
    depends_on = [ azurerm_resource_group.Spoke_01 ]
}

# Create the Subnets with address prefixes
resource "azurerm_subnet" "subnets" {
  for_each = var.subnet_details
  name = each.key
  address_prefixes = [each.value.address_prefix]
  virtual_network_name = azurerm_virtual_network.Spoke_01_vnet["Spoke_01_vnet"].name
  resource_group_name = azurerm_resource_group.Spoke_01["Spoke_01_RG"].name
  depends_on = [ azurerm_virtual_network.Spoke_01_vnet ]
}

# Create the Network Security Group with Rules
resource "azurerm_network_security_group" "nsg" {
  for_each = toset(local.subnet_names)
  name = each.key
  resource_group_name = azurerm_resource_group.Spoke_01["Spoke_01_RG"].name
  location = azurerm_resource_group.Spoke_01["Spoke_01_RG"].location

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
resource "azurerm_subnet_network_security_group_association" "nsg_ass" {
  for_each = { for idx , subnet in azurerm_subnet.subnets : idx => subnet.id}
  subnet_id                 = each.value
  network_security_group_id =   azurerm_network_security_group.nsg[local.nsg_names[each.key]].id
  depends_on = [ azurerm_network_security_group.nsg ]
}

# Create the Availability Set for High availability
resource "azurerm_availability_set" "av-set" {
  name                = "av-set"
  resource_group_name = azurerm_resource_group.Spoke_01["Spoke_01_RG"].name
  location = azurerm_resource_group.Spoke_01["Spoke_01_RG"].location
 
  managed            = true
  platform_fault_domain_count = 2
  platform_update_domain_count = 2
  depends_on = [ azurerm_resource_group.Spoke_01 ]
}

# Create the Network Interface card for Virtual Machines
resource "azurerm_network_interface" "subnet_nic" {
  for_each = toset(local.subnet_names)
  name                = "${each.key}-NIC"
  resource_group_name = azurerm_resource_group.Spoke_01["Spoke_01_RG"].name
  location = azurerm_resource_group.Spoke_01["Spoke_01_RG"].location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnets[local.nsg_names[each.key]].id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [ azurerm_virtual_network.Spoke_01_vnet , azurerm_subnet.subnets ]
}

# Create the Virtual Machines(VM) in Availability Set and assign the NIC to specific VMs
resource "azurerm_windows_virtual_machine" "VMs" {
  name                  = "${azurerm_subnet.subnets[local.nsg_names[each.key]].name}-VM"
  resource_group_name = azurerm_resource_group.Spoke_01["Spoke_01_RG"].name
  location = azurerm_resource_group.Spoke_01["Spoke_01_RG"].location
  size                  = "Standard_DS1_v2"
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  for_each = {for idx , nic in azurerm_network_interface.subnet_nic : idx => nic.id}
  network_interface_ids = [each.value]
   availability_set_id =azurerm_availability_set.av-set.id

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  depends_on = [ azurerm_network_interface.subnet_nic ]
}

# Create the Storage account for FileShare
resource "azurerm_storage_account" "storage-account" {
  name                     = "storageaccount160302"
  resource_group_name =     azurerm_resource_group.Spoke_01["Spoke_01_RG"].name
  location                 = azurerm_resource_group.Spoke_01["Spoke_01_RG"].location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  depends_on = [ azurerm_resource_group.Spoke_01  ]
}
 
# Create the FileShare in Storage account
resource "azurerm_storage_share" "example" {
  name                 = "exampleshare"
  storage_account_name = azurerm_storage_account.storage-account.name
  quota                = 5
  depends_on = [ azurerm_resource_group.Spoke_01 , azurerm_storage_account.storage-account ]
}

# Fetch the data from Hub Virtual Network for peering the Spoke_01 Virtual Network (Spoke_01 <--> Hub)
data "azurerm_virtual_network" "Hub_vnet" {
  name = "Hub_vnet"
  resource_group_name = "Hub_RG"
}

# Establish the Peering between Spoke_01 and Hub networks (Spoke_01 <--> Hub)
resource "azurerm_virtual_network_peering" "Spoke_01-To-Hub" {
  name                      = "Spoke_01-To-Hub"
  resource_group_name       = azurerm_virtual_network.Spoke_01_vnet["Spoke_01_vnet"].resource_group_name
  virtual_network_name      = azurerm_virtual_network.Spoke_01_vnet["Spoke_01_vnet"].name
  remote_virtual_network_id = data.azurerm_virtual_network.Hub_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.Spoke_01_vnet , data.azurerm_virtual_network.Hub_vnet  ]
}

# Establish the Peering between and Hub Spoke_01 networks (Hub <--> Spoke_01)
resource "azurerm_virtual_network_peering" "Hub-Spoke_01" {
  name                      = "Hub-Spoke_01"
  resource_group_name       = data.azurerm_virtual_network.Hub_vnet.resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.Hub_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.Spoke_01_vnet["Spoke_01_vnet"].id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.Spoke_01_vnet , data.azurerm_virtual_network.Hub_vnet ]
}

# resource "azurerm_virtual_machine_extension" "vm_extension" {
#   //for_each = [for vm in azurerm_windows_virtual_machine.VMs : vm.name]
#   name                 = "${azurerm_windows_virtual_machine.VMs["Web"].name}-vm-ext"
#   virtual_machine_id   = azurerm_windows_virtual_machine.VMs["Web"].id
#   publisher            = "Microsoft.Compute"
#   type                 = "CustomScriptExtension"
#   type_handler_version = "1.10"

#   settings = <<SETTINGS
#     {
#         "commandToExecute": "powershell -ExecutionPolicy Unrestricted -Command \\"$acctName = '${azurerm_storage_account.storage-account.name}'; $acctKey = '${azurerm_storage_account.storage-account.primary_access_key}'; net use Z: \\\\'${azurerm_storage_account.storage-account.name}.file.core.windows.net\\${azurerm_storage_share.example.name} /user:$acctName $acctKey\\""
#     }
#   SETTINGS
# }

