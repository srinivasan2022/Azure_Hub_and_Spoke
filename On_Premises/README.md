<!-- BEGIN_TF_DOCS -->
## On\_Premises Network :
- 1.First we have to create the Resource Group for On\_Premises.
- 2.We should create the Virtual Network for Hub with address space.
- 3.The Hub Virtual Network has multiple subnets with address prefixes.
- 4.We have to create the subnet for VPN Gateway.
- 5.We should create the Local Network Gateway and Connection service for establish the connection between On\_premises and Hub.

## Architecture Diagram :

```hcl
# Create the Resource Group
resource "azurerm_resource_group" "On_Premises" {
   for_each = var.rg_details
   name     = each.value.rg_name
   location = each.value.rg_location
}

# Create the Virtual Network with address space
resource "azurerm_virtual_network" "On_Premises_vnet" {
    for_each = var.vnet_details
    name = each.value.vnet_name
    address_space = [each.value.address_space]
    resource_group_name = azurerm_resource_group.On_Premises["On_Premises_RG"].name
    location = azurerm_resource_group.On_Premises["On_Premises_RG"].location
    depends_on = [ azurerm_resource_group.On_Premises ]
}

# Create the Subnets with address prefixes
resource "azurerm_subnet" "subnets" {
  for_each = var.subnet_details
  name = each.key
  address_prefixes = [each.value.address_prefix]
  virtual_network_name = azurerm_virtual_network.On_Premises_vnet["On_Premises_vnet"].name
  resource_group_name = azurerm_resource_group.On_Premises["On_Premises_RG"].name
  depends_on = [ azurerm_virtual_network.On_Premises_vnet ]
}

# Create the Public IP for VPN Gateway 
resource "azurerm_public_ip" "public_ips" {
  name = "OnPremise-VPN-${azurerm_subnet.subnets["GatewaySubnet"].name}-IP"
  location            = azurerm_resource_group.On_Premises["On_Premises_RG"].location
  resource_group_name = azurerm_resource_group.On_Premises["On_Premises_RG"].name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on = [ azurerm_resource_group.On_Premises ]
}

# Create the VPN Gateway in their Specified Subnet
resource "azurerm_virtual_network_gateway" "gateway" {
  name                = "OnPremise-VPN-gateway"
  location            = azurerm_resource_group.On_Premises["On_Premises_RG"].location
  resource_group_name = azurerm_resource_group.On_Premises["On_Premises_RG"].name
 
  type     = "Vpn"
  vpn_type = "RouteBased"
  active_active = false
  enable_bgp    = false
  sku           = "VpnGw1"
 
  ip_configuration {
    name                = "vnetGatewayConfig"
    public_ip_address_id = azurerm_public_ip.public_ips["GatewaySubnet"].id
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
  location            = azurerm_resource_group.On_Premises["On_Premises_RG"].location
  resource_group_name = azurerm_resource_group.On_Premises["On_Premises_RG"].name
  gateway_address     = data.azurerm_public_ip.Hub-VPN-GW-public-ip.ip_address
  address_space       = [data.azurerm_virtual_network.Hub_vnet.address_space[0]]
  depends_on = [ azurerm_public_ip.public_ips , azurerm_virtual_network_gateway.gateway ,
               data.azurerm_public_ip.Hub-VPN-GW-public-ip , data.azurerm_virtual_network.Hub_vnet ]
}

# Create the VPN-Connection for Connecting the Networks
resource "azurerm_virtual_network_gateway_connection" "vpn_connection" {
  name                = "OnPremises-Hub-vpn-connection"
  location            = azurerm_resource_group.On_Premises["On_Premises_RG"].location
  resource_group_name = azurerm_resource_group.On_Premises["On_Premises_RG"].name
  virtual_network_gateway_id     = azurerm_virtual_network_gateway.gateway.id
  local_network_gateway_id       = azurerm_local_network_gateway.OnPremises_local_gateway.id
  type                           = "IPsec"
  connection_protocol            = "IKEv2"
  shared_key                     = "YourSharedKey"

  depends_on = [ azurerm_virtual_network_gateway.gateway , azurerm_local_network_gateway.OnPremises_local_gateway]
}

 # ------------------

# # Create the Network Interface card for Virtual Machines
# resource "azurerm_network_interface" "subnet_nic" {
#   for_each = toset(local.subnet_names)
#   name                = "${each.key}-NIC"
#   resource_group_name = azurerm_resource_group.On_Premises["On_Premises_RG"].name
#   location = azurerm_resource_group.On_Premises["On_Premises_RG"].location

#   ip_configuration {
#     name                          = "internal"
#     subnet_id                     = azurerm_subnet.subnets[local.subnet_names[each.key]].id
#     private_ip_address_allocation = "Dynamic"
#   }
#   depends_on = [ azurerm_virtual_network.On_Premises_vnet , azurerm_subnet.subnets ]
# }

# # Create the Virtual Machines(VM) and assign the NIC to specific VMs
# resource "azurerm_windows_virtual_machine" "VMs" {
#   for_each = toset(local.subnet_names)
#   name = "${each.key}-VM"
#   //name                  = "${azurerm_subnet.subnets[local.subnet_names[each.key]].name}-VM"
#   resource_group_name = azurerm_resource_group.Spoke_01["On_Premises_RG"].name
#   location = azurerm_resource_group.Spoke_01["On_Premises_RG"].location
#   size                  = "Standard_DS1_v2"
#   admin_username        = var.admin_username
#   admin_password        = var.admin_password
#   //for_each = {for idx , nic in azurerm_network_interface.subnet_nic : idx => nic.id}
#   network_interface_ids = [azurerm_network_interface.subnet_nic[local.NIC_names[each.key]].id]
#   //network_interface_ids = [each.value]

#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#   }

#   source_image_reference {
#     publisher = "MicrosoftWindowsServer"
#     offer     = "WindowsServer"
#     sku       = "2019-Datacenter"
#     version   = "latest"
#   }
#   depends_on = [ azurerm_network_interface.subnet_nic ]
# }
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
- [azurerm_public_ip.public_ips](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) (resource)
- [azurerm_resource_group.On_Premises](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_subnet.subnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_virtual_network.On_Premises_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [azurerm_virtual_network_gateway.gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway) (resource)
- [azurerm_virtual_network_gateway_connection.vpn_connection](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway_connection) (resource)
- [azurerm_public_ip.Hub-VPN-GW-public-ip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/public_ip) (data source)
- [azurerm_virtual_network.Hub_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

No required inputs.

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password)

Description: n/a

Type: `string`

Default: `"pass@word1234"`

### <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username)

Description: n/a

Type: `string`

Default: `"azureuser"`

### <a name="input_rg_details"></a> [rg\_details](#input\_rg\_details)

Description: n/a

Type:

```hcl
map(object({
    rg_name = string
    rg_location = string
  }))
```

Default:

```json
{
  "On_Premises_RG": {
    "rg_location": "East us",
    "rg_name": "On_Premises_RG"
  }
}
```

### <a name="input_subnet_details"></a> [subnet\_details](#input\_subnet\_details)

Description: n/a

Type:

```hcl
map(object({
    subnet_name = string
    address_prefix = string
  }))
```

Default:

```json
{
  "DB": {
    "address_prefix": "10.100.2.0/24",
    "subnet_name": "DB"
  },
  "GatewaySubnet": {
    "address_prefix": "10.100.1.0/24",
    "subnet_name": "GatewaySubnet"
  }
}
```

### <a name="input_vnet_details"></a> [vnet\_details](#input\_vnet\_details)

Description: n/a

Type:

```hcl
map(object({
    vnet_name = string
    address_space = string
  }))
```

Default:

```json
{
  "On_Premises_vnet": {
    "address_space": "10.100.0.0/16",
    "vnet_name": "On_Premises_vnet"
  }
}
```

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

### <a name="output_VPN_Gateway"></a> [VPN\_Gateway](#output\_VPN\_Gateway)

Description: n/a

## Modules

No modules.

This is the On\_Premises Network Configuration Terraform Files.
<!-- END_TF_DOCS -->