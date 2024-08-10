data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}

# Create the Resource Group
resource "azurerm_resource_group" "On_Premises" {
   name     = var.rg_name
   location = var.rg_location
}

# Create the Virtual Network with address space
resource "azurerm_virtual_network" "On_Premises_vnet" {
    for_each = var.vnet_details
    name = each.value.vnet_name
    address_space = [each.value.address_space]
    resource_group_name = azurerm_resource_group.On_Premises.name
    location = azurerm_resource_group.On_Premises.location
    depends_on = [ azurerm_resource_group.On_Premises ]
}

# Create the Subnets with address prefixes
resource "azurerm_subnet" "subnets" {
  for_each = var.subnet_details
  name = each.key
  address_prefixes = [each.value.address_prefix]
  virtual_network_name = azurerm_virtual_network.On_Premises_vnet["On_Premises_vnet"].name
  resource_group_name = azurerm_resource_group.On_Premises.name
  depends_on = [ azurerm_virtual_network.On_Premises_vnet ]
}

# Create the Public IP for VPN Gateway 
resource "azurerm_public_ip" "public_ips" {
  name = "OnPremise-VPN-${azurerm_subnet.subnets["GatewaySubnet"].name}-IP"  
  location            = azurerm_resource_group.On_Premises.location
  resource_group_name = azurerm_resource_group.On_Premises.name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on = [ azurerm_resource_group.On_Premises ]
}

# Create the VPN Gateway in their Specified Subnet
resource "azurerm_virtual_network_gateway" "gateway" {
  name                = "OnPremise-VPN-gateway"
  location            = azurerm_resource_group.On_Premises.location
  resource_group_name = azurerm_resource_group.On_Premises.name
 
  type     = "Vpn"
  vpn_type = "RouteBased"
  active_active = false
  enable_bgp    = false
  sku           = "VpnGw1"
 
  ip_configuration {
    name                = "vnetGatewayConfig"
    public_ip_address_id = azurerm_public_ip.public_ips.id
    private_ip_address_allocation = "Dynamic"
    subnet_id = azurerm_subnet.subnets["GatewaySubnet"].id
  }
  depends_on = [ azurerm_resource_group.On_Premises , azurerm_public_ip.public_ips , azurerm_subnet.subnets ]
}

# Fetch the data from Hub Gateway Public_IP (IP_address)
data "azurerm_public_ip" "Hub-VPN-GW-public-ip" {
  name = "GatewaySubnet-IP"
  resource_group_name = "Hub_RG"
}

# Fetch the data from Hub Virtual Network (address_space)
data "azurerm_virtual_network" "Hub_vnet" {
  name = "Hub_vnet"
  resource_group_name = "Hub_RG"
}

# Create the Local Network Gateway for VPN Gateway
resource "azurerm_local_network_gateway" "OnPremises_local_gateway" {
  name                = "OnPremises-To-Hub"
  location            = azurerm_virtual_network_gateway.gateway.resource_group_name
  resource_group_name = azurerm_virtual_network_gateway.gateway.location
  gateway_address     = data.azurerm_public_ip.Hub-VPN-GW-public-ip.ip_address     # Replace the Hub-VPN Public-IP
  address_space       = [data.azurerm_virtual_network.Hub_vnet.address_space[0]]   # Replace the Hub-Vnet address space
  depends_on = [ azurerm_public_ip.public_ips , azurerm_virtual_network_gateway.gateway ,
               data.azurerm_public_ip.Hub-VPN-GW-public-ip , data.azurerm_virtual_network.Hub_vnet ]
}

# Create the VPN-Connection for Connecting the Networks
resource "azurerm_virtual_network_gateway_connection" "vpn_connection" {
  name                = "OnPremises-Hub-vpn-connection"
  location            = azurerm_virtual_network_gateway.gateway.resource_group_name
  resource_group_name = azurerm_virtual_network_gateway.gateway.location
  virtual_network_gateway_id     = azurerm_virtual_network_gateway.gateway.id
  local_network_gateway_id       = azurerm_local_network_gateway.OnPremises_local_gateway.id
  type                           = "IPsec"
  connection_protocol            = "IKEv2"
  shared_key                     = "YourSharedKey"

  depends_on = [ azurerm_virtual_network_gateway.gateway , azurerm_local_network_gateway.OnPremises_local_gateway]
}


# Create the Network Interface card for Virtual Machines
resource "azurerm_network_interface" "subnet_nic" {
  name                = "DB-NIC"
  resource_group_name = azurerm_resource_group.On_Premises.name
  location = azurerm_resource_group.On_Premises.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnets["OnPremSubnet"].id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [ azurerm_virtual_network.On_Premises_vnet , azurerm_subnet.subnets ]
}

# Creates the Azure Key vault to store the VM username and password
resource "azurerm_key_vault" "Key_vault" {
  name                        = var.Key_vault_name
  resource_group_name = azurerm_resource_group.On_Premises.name
  location = azurerm_resource_group.On_Premises.location
  sku_name                    = "standard"
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled    = true
  soft_delete_retention_days = 30
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azuread_client_config.current.object_id

    secret_permissions = [
      "Get",
      "Set",
      "Backup",
      "Delete",
      "Purge", 
      "List",
      "Recover",
      "Restore",
    ]
  }
  depends_on = [ azurerm_resource_group.On_Premises ]
}

# Creates the Azure Key vault secret to store the VM username and password
resource "azurerm_key_vault_secret" "vm_admin_username" {
  name         = "Spokevmvirtualmachineusername"
  value        = var.admin_username
  key_vault_id = azurerm_key_vault.Key_vault.id
  depends_on = [ azurerm_key_vault.Key_vault ]
}

# Creates the Azure Key vault secret to store the VM username and password
resource "azurerm_key_vault_secret" "vm_admin_password" {
  name         = "Spokevmvirtualmachinepassword"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.Key_vault.id
  depends_on = [ azurerm_key_vault.Key_vault ]
}

# Create the Virtual Machines(VM) and assign the NIC to specific VM
resource "azurerm_windows_virtual_machine" "VMs" {
  name = "OnPrem-VM"
  resource_group_name = azurerm_resource_group.On_Premises.name
  location = azurerm_resource_group.On_Premises.location
  size                  = "Standard_DS1_v2"
  admin_username        = azurerm_key_vault_secret.vm_admin_username.value
  admin_password        = azurerm_key_vault_secret.vm_admin_password.value
  network_interface_ids = [azurerm_network_interface.subnet_nic.id]

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
  depends_on = [ azurerm_network_interface.subnet_nic , azurerm_key_vault_secret.vm_admin_password , azurerm_key_vault_secret.vm_admin_username]
}

# Creates the route table
resource "azurerm_route_table" "route_table" {
  name                = "Onprem-Spoke"
  resource_group_name = azurerm_resource_group.On_Premises.name
  location = azurerm_resource_group.On_Premises.location
  depends_on = [ azurerm_resource_group.On_Premises , azurerm_subnet.subnets ]
}

# Creates the route in the route table (OnPrem-Firewall-Spoke)
resource "azurerm_route" "route_01" {
  name                   = "ToSpoke01"
  resource_group_name = azurerm_resource_group.On_Premises.name
  route_table_name = azurerm_route_table.route_table.name
  address_prefix = "10.20.0.0/16"     # destnation network address space
  next_hop_type      = "VirtualNetworkGateway" 
  depends_on = [ azurerm_route_table.route_table ]
}

# Associate the route table with their subnet
resource "azurerm_subnet_route_table_association" "RT-ass" {
   subnet_id                 = azurerm_subnet.subnets["OnPremSubnet"].id
   route_table_id = azurerm_route_table.route_table.id
   depends_on = [ azurerm_subnet.subnets , azurerm_route_table.route_table ]
}
