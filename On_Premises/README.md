<!-- BEGIN_TF_DOCS -->
## On\_Premises Network :
- 1.First we have to create the Resource Group for On\_Premises.
- 2.We should create the Virtual Network for Hub with address space.
- 3.The Hub Virtual Network has multiple subnets with address prefixes.
- 4.We have to create the subnet for VPN Gateway.
- 5.We should create the Local Network Gateway and Connection service for establish the connection between On\_premises and Hub.

## Architecture Diagram :
![On\_Premises](https://github.com/user-attachments/assets/0baf48b4-dbc2-437d-9ded-f530f33f23d9)

###### Apply the Terraform configurations :
Deploy the resources using Terraform,
```
terraform init
```
```
terraform plan "--var-file=variables.tfvars"
```
```
terraform apply "--var-file=variables.tfvars"
```

```hcl
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

# Fetch the data from key vault
data "azurerm_key_vault" "Key_vault" {
  name                = "MyKeyVault1603"
  resource_group_name = "Spoke_01_RG"
}

# Get the username from key vault secret store
data "azurerm_key_vault_secret" "vm_admin_username" {
  name         = "Spokevmvirtualmachineusername"
  key_vault_id = data.azurerm_key_vault.Key_vault.id
}

# Get the password from key vault secret store
data "azurerm_key_vault_secret" "vm_admin_password" {
  name         = "Spokevmvirtualmachinepassword"
  key_vault_id = data.azurerm_key_vault.Key_vault.id
}

# Create the Virtual Machines(VM) and assign the NIC to specific VM
resource "azurerm_windows_virtual_machine" "VMs" {
  name = "OnPrem-VM"
  resource_group_name = azurerm_resource_group.On_Premises.name
  location = azurerm_resource_group.On_Premises.location
  size                  = "Standard_DS1_v2"
  admin_username        = data.azurerm_key_vault_secret.vm_admin_username.value
  admin_password        = data.azurerm_key_vault_secret.vm_admin_password.value
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
  depends_on = [ azurerm_network_interface.subnet_nic , data.azurerm_key_vault_secret.vm_admin_password , data.azurerm_key_vault_secret.vm_admin_username]
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
```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.1.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (~> 3.0.2)

## Providers

The following providers are used by this module:

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (~> 3.0.2)

## Resources

The following resources are used by this module:

- [azurerm_local_network_gateway.OnPremises_local_gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/local_network_gateway) (resource)
- [azurerm_network_interface.subnet_nic](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) (resource)
- [azurerm_public_ip.public_ips](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) (resource)
- [azurerm_resource_group.On_Premises](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_route.route_01](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route) (resource)
- [azurerm_route_table.route_table](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_table) (resource)
- [azurerm_subnet.subnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet_route_table_association.RT-ass](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_route_table_association) (resource)
- [azurerm_virtual_network.On_Premises_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [azurerm_virtual_network_gateway.gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway) (resource)
- [azurerm_virtual_network_gateway_connection.vpn_connection](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway_connection) (resource)
- [azurerm_windows_virtual_machine.VMs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine) (resource)
- [azurerm_key_vault.Key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) (data source)
- [azurerm_key_vault_secret.vm_admin_password](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) (data source)
- [azurerm_key_vault_secret.vm_admin_username](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) (data source)
- [azurerm_public_ip.Hub-VPN-GW-public-ip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/public_ip) (data source)
- [azurerm_virtual_network.Hub_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_rg_location"></a> [rg\_location](#input\_rg\_location)

Description: The Location of the Resource Group

Type: `string`

### <a name="input_rg_name"></a> [rg\_name](#input\_rg\_name)

Description: The name of the Resource Group

Type: `string`

### <a name="input_subnet_details"></a> [subnet\_details](#input\_subnet\_details)

Description: The details of the Subnets

Type:

```hcl
map(object({
    subnet_name = string
    address_prefix = string
  }))
```

### <a name="input_vnet_details"></a> [vnet\_details](#input\_vnet\_details)

Description: The details of the VNET

Type:

```hcl
map(object({
    vnet_name = string
    address_space = string
  }))
```

## Optional Inputs

No optional inputs.

## Outputs

The following outputs are exported:

### <a name="output_On_Premise_RG"></a> [On\_Premise\_RG](#output\_On\_Premise\_RG)

Description: n/a

### <a name="output_On_Premise_vnet_"></a> [On\_Premise\_vnet\_](#output\_On\_Premise\_vnet\_)

Description: n/a

### <a name="output_Public_ips"></a> [Public\_ips](#output\_Public\_ips)

Description: n/a

### <a name="output_Subnet_details"></a> [Subnet\_details](#output\_Subnet\_details)

Description: n/a

## Modules

No modules.

This is the On\_Premises Network Configuration Terraform Files.
<!-- END_TF_DOCS -->