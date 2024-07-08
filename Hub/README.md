<!-- BEGIN_TF_DOCS -->
## Hub Network :
- 1.First we have to create the Resource Group for Hub.
- 2.We should create the Virtual Network for Hub with address space.
- 3.The Hub Virtual Network has multiple subnets with address prefixes.
- 4.We have to create the subnets for Firewall,VPN Gateway,Bastion and AppserviceSubnet.
- 5.Dedicated subnets : AzureFirewallSubnet, GatewaySubnet.
- 6.We should create the Local Network Gateway and Connection service for establish the connection between On\_premises and Hub.

## Architecture Diagram :
![HUB](https://github.com/srinivasan2022/Project/assets/118502121/c8c76565-bee9-40d8-a214-fc10a26e259b)

```hcl
# Create the Resource Group
resource "azurerm_resource_group" "Hub" {
   for_each = var.rg_details
   name     = each.value.rg_name
   location = each.value.rg_location 
}

# Create the Virtual Network with address space
resource "azurerm_virtual_network" "Hub_vnet" {
    for_each = var.vnet_details
    name = each.value.vnet_name
    address_space = [each.value.address_space]
    resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
    location = azurerm_resource_group.Hub["Hub_RG"].location
    depends_on = [ azurerm_resource_group.Hub ]
}

# Create the Subnets with address prefixes
resource "azurerm_subnet" "subnets" {
  for_each = var.subnet_details
  name = each.key
  address_prefixes = [each.value.address_prefix]
  virtual_network_name = azurerm_virtual_network.Hub_vnet["Hub_vnet"].name
  resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
  depends_on = [ azurerm_virtual_network.Hub_vnet ]
}

# Creates the individual subnet for virtual network integration to connect the App services
resource "azurerm_subnet" "AppServiceSubnet" {
  for_each = var.appService_subnet
  name = each.key
  address_prefixes = [each.value.address_prefix]
  virtual_network_name = azurerm_virtual_network.Hub_vnet["Hub_vnet"].name
  resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
  delegation {
    name = "appservice_delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }
  depends_on = [ azurerm_virtual_network.Hub_vnet ]
}


# Create the Public IP's for Azure Firewall , VPN Gateway and Azure Bastion Host 
resource "azurerm_public_ip" "public_ips" {
  for_each = toset(local.subnet_names)
  name = "${each.key}-IP"
  location            = azurerm_resource_group.Hub["Hub_RG"].location
  resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on = [ azurerm_resource_group.Hub ]
}
 
 # Create the Network Interface card for Network Virtual Appliances(NVA)
resource "azurerm_network_interface" "nva_nic" {
  name                = "nva-NIC"
  location            = azurerm_resource_group.Hub["Hub_RG"].location
  resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnets["NVASubnet"].id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [ azurerm_virtual_network.Hub_vnet , azurerm_subnet.subnets ]
}

# Create the Virtual Machines(VM) and assign the NIC to specific VMs
resource "azurerm_windows_virtual_machine" "nva" {
  name = "NVA"
  location            = azurerm_resource_group.Hub["Hub_RG"].location
  resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
  size                  = "Standard_DS1_v2"
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.nva_nic.id]

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
  depends_on = [ azurerm_network_interface.nva_nic ]
}

# Create the Azure Bastion Host
resource "azurerm_bastion_host" "bastion" {
  name                = "Bastion"
  location            = azurerm_resource_group.Hub["Hub_RG"].location
  resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
  sku = "Standard"
  ip_configuration {
    public_ip_address_id = azurerm_public_ip.public_ips["AzureBastionSubnet"].id
    name = "example"
    subnet_id = azurerm_subnet.subnets["AzureBastionSubnet"].id
  }
  depends_on = [ azurerm_resource_group.Hub , azurerm_public_ip.public_ips , azurerm_subnet.subnets ]
}

resource "azurerm_firewall_policy" "firewall_policy" {
  name                = "example-firewall-policy"
  location            = azurerm_resource_group.Hub["Hub_RG"].location
  resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
  sku = "Standard"
  depends_on = [ azurerm_resource_group.Hub , azurerm_subnet.subnets ]
}
 
# Create the Azure Firewall in their Specified Subnet
resource "azurerm_firewall" "firewall" {
  name                = "Firewall"
  location            = azurerm_resource_group.Hub["Hub_RG"].location
  resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
   sku_name = "AZFW_VNet"
   sku_tier = "Standard"

  ip_configuration {
    name                 = "firewallconfiguration"
    subnet_id            = azurerm_subnet.subnets["AzureFirewallSubnet"].id
    public_ip_address_id = azurerm_public_ip.public_ips["AzureFirewallSubnet"].id
  }
  firewall_policy_id = azurerm_firewall_policy.firewall_policy.id
  depends_on = [ azurerm_resource_group.Hub , azurerm_public_ip.public_ips , 
  azurerm_subnet.subnets , azurerm_firewall_policy.firewall_policy ]
}

# resource "azurerm_firewall_application_rule_collection" "fw_app_rule_collection" {
#   name                = "example-app-rule"
#   azure_firewall_name = azurerm_firewall.firewall.name
#   resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
#   priority            = 200
#   action              = "Allow"

#   rule {
#     name                  = "allow-http"
#     source_addresses      = ["10.20.1.4"]
#     protocol {
#       port = 80
#       type = "Http"
#     }
#     protocol {
#       port = 443
#       type = "Https"
#     }

#     target_fqdns = ["microsoft.com"]
#   }
#   depends_on = [ azurerm_firewall.firewall , azurerm_firewall_policy.firewall_policy ]
# }

# Create the Firewall policy rule collection
resource "azurerm_firewall_policy_rule_collection_group" "fw_policy_rule_collection" {
  name                = "app-rule-collection-group"
  firewall_policy_id  = azurerm_firewall_policy.firewall_policy.id
  priority            = 100
 
  # network_rule_collection {
  #   name     = "network-rule-collection"
  #   priority = 200
  #   action   = "Allow"
 
  #   rule {
  #     name                  = "allow-dns"
  #     description           = "Allow DNS"
  #     rule_type             = "NetworkRule"
  #     source_addresses      = ["*"]
  #     destination_addresses = ["*"]
  #     destination_ports     = ["53"]
  #     protocols             = ["UDP", "TCP"]
  #   }
  # }
 
  application_rule_collection {       # Create the Application rule collection
    name     = "application-rule-collection"
    priority = 300
    action   = "Allow"
 
    rule {
      name             = "allow-web"
      description      = "Allow-Web-Access"
      source_addresses = ["10.20.1.4"]  # Allow traffic only from [10.20.1.4]
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      } 
      destination_fqdns = ["*.microsoft.com"]  
    }
  } 
}

# # Create the VPN Gateway in their Specified Subnet
# resource "azurerm_virtual_network_gateway" "gateway" {
#   name                = "Hub-vpn-gateway"
#   location            = azurerm_resource_group.Hub["Hub_RG"].location
#   resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
 
#   type     = "Vpn"
#   vpn_type = "RouteBased"
#   active_active = false
#   enable_bgp    = false
#   sku           = "VpnGw1"
 
#   ip_configuration {
#     name                = "vnetGatewayConfig"
#     public_ip_address_id = azurerm_public_ip.public_ips["GatewaySubnet"].id
#     private_ip_address_allocation = "Dynamic"
#     subnet_id = azurerm_subnet.subnets["GatewaySubnet"].id
#   }
#   depends_on = [ azurerm_resource_group.Hub , azurerm_public_ip.public_ips , azurerm_subnet.subnets ]
# }

# # Fetch the data from On_premises Gateway Public_IP (IP_address)
# data "azurerm_public_ip" "OnPrem-VPN-GW-public-ip" {
#   name = "OnPremise-VPN-GatewaySubnet-IP"
#   resource_group_name = "On_Premises_RG"
# }

# # Fetch the data from On_Premise Virtual Network (address_space)
# data "azurerm_virtual_network" "On_Premises_vnet" {
#   name = "On_Premises_vnet"
#   resource_group_name = "On_Premises_RG"
# }


# # Create the Local Network Gateway for VPN Gateway
# resource "azurerm_local_network_gateway" "Hub_local_gateway" {
#   name                = "Hub-To-OnPremises"
#   location            = azurerm_resource_group.Hub["Hub_RG"].location
#   resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
#   gateway_address     = data.azurerm_public_ip.OnPrem-VPN-GW-public-ip.ip_address
#   address_space       = [data.azurerm_virtual_network.On_Premises_vnet.address_space[0]]
#   depends_on = [ azurerm_public_ip.public_ips , azurerm_virtual_network_gateway.gateway , 
#               data.azurerm_public_ip.OnPrem-VPN-GW-public-ip ,data.azurerm_virtual_network.On_Premises_vnet ]
# }

#  # Create the VPN-Connection for Connecting the Networks
# resource "azurerm_virtual_network_gateway_connection" "vpn_connection" {
#   name                           = "Hub-OnPremises-vpn-connection"
#   location            = azurerm_resource_group.Hub["Hub_RG"].location
#   resource_group_name = azurerm_resource_group.Hub["Hub_RG"].name
#   virtual_network_gateway_id     = azurerm_virtual_network_gateway.gateway.id
#   local_network_gateway_id       = azurerm_local_network_gateway.Hub_local_gateway.id
#   type                           = "IPsec"
#   connection_protocol            = "IKEv2"
#   shared_key                     = "YourSharedKey"

#   depends_on = [ azurerm_virtual_network_gateway.gateway , azurerm_local_network_gateway.Hub_local_gateway]
# }

# # Creates the policy definition
# resource "azurerm_policy_definition" "rg_policy_def" {
#   name         = "Hub_rg-policy"
#   policy_type  = "Custom"
#   mode         = "All"
#   display_name = "Hub Policy"
#   description  = "A policy to demonstrate resource group level policy."
 
#   policy_rule = <<POLICY_RULE
#   {
#     "if": {
#       "field": "location",
#       "equals": "East US"
#     },
#     "then": {
#       "effect": "deny"
#     }
#   }
#   POLICY_RULE
 
#   metadata = <<METADATA
#   {
#     "category": "General"
#   }
#   METADATA
# }
 
# # Assign the policy
# resource "azurerm_policy_assignment" "example" {
#   name                 = "Hub-rg-policy-assignment"
#   policy_definition_id = azurerm_policy_definition.rg_policy_def.id
#   scope                = azurerm_resource_group.Hub["Hub_RG"].id
#   display_name         = "Hub_RG Policy Assignment"
#   description          = "Assigning policy to the resource group"
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

- [azurerm_bastion_host.bastion](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/bastion_host) (resource)
- [azurerm_firewall.firewall](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall) (resource)
- [azurerm_firewall_policy.firewall_policy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall_policy) (resource)
- [azurerm_firewall_policy_rule_collection_group.fw_policy_rule_collection](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall_policy_rule_collection_group) (resource)
- [azurerm_network_interface.nva_nic](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) (resource)
- [azurerm_public_ip.public_ips](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) (resource)
- [azurerm_resource_group.Hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_subnet.AppServiceSubnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet.subnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_virtual_network.Hub_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [azurerm_windows_virtual_machine.nva](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine) (resource)

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

### <a name="input_appService_subnet"></a> [appService\_subnet](#input\_appService\_subnet)

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
  "AppServiceSubnet": {
    "address_prefix": "10.10.3.0/27",
    "subnet_name": "AppServiceSubnet"
  }
}
```

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
  "Hub_RG": {
    "rg_location": "East us",
    "rg_name": "Hub_RG"
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
  "AzureBastionSubnet": {
    "address_prefix": "10.10.2.0/24",
    "subnet_name": "AzureBastionSubnet"
  },
  "AzureFirewallSubnet": {
    "address_prefix": "10.10.0.0/26",
    "subnet_name": "AzureFirewallSubnet"
  },
  "GatewaySubnet": {
    "address_prefix": "10.10.1.0/27",
    "subnet_name": "GatewaySubnet"
  },
  "NVASubnet": {
    "address_prefix": "10.10.4.0/24",
    "subnet_name": "NVASubnet"
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
  "Hub_vnet": {
    "address_space": "10.10.0.0/16",
    "vnet_name": "Hub_vnet"
  }
}
```

## Outputs

The following outputs are exported:

### <a name="output_Hub_RG"></a> [Hub\_RG](#output\_Hub\_RG)

Description: n/a

### <a name="output_Hub_vnet_"></a> [Hub\_vnet\_](#output\_Hub\_vnet\_)

Description: n/a

### <a name="output_Subnet_details"></a> [Subnet\_details](#output\_Subnet\_details)

Description: n/a

## Modules

No modules.

This is the Hub Network Configuration Terraform Files.
<!-- END_TF_DOCS -->