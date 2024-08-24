<!-- BEGIN_TF_DOCS -->
## Spoke\_03 Network :
- 1.First we have to create the Resource Group for Spoke\_03.
- 2.We create the virtual network with subnets.
- 3.Then, we create the app service plan for app services.
- 4.We create the app services in their app services plan.
- 5.Finally we have to establish the virtual network integration to connect the app services.

## Architecture Diagram :
![SPOKE\_03](https://github.com/user-attachments/assets/8864b991-0f53-4b0b-8a53-9d7a1e02b38f)

###### Apply the Terraform configurations :
Deploy the resources using Terraform,
```
terraform init
```
```
terraform plan
```
```
terraform apply
```

```hcl
# Create a resource group
resource "azurerm_resource_group" "Spoke_03" {
  name     = var.rg_name
  location = var.rg_location
}

# Create the Virtual Network with address space
resource "azurerm_virtual_network" "Spoke_03_vnet" {
    for_each = var.vnet_details
    name = each.value.vnet_name
    address_space = [each.value.address_space]
    resource_group_name = azurerm_resource_group.Spoke_03.name
    location = azurerm_resource_group.Spoke_03.location
    depends_on = [ azurerm_resource_group.Spoke_03 ]
}

# Create the Subnets with address prefixes
resource "azurerm_subnet" "subnets" {
  for_each = var.subnet_details
  name = each.key
  address_prefixes = [each.value.address_prefix]
  virtual_network_name = azurerm_virtual_network.Spoke_03_vnet["Spoke_03_vnet"].name
  resource_group_name = azurerm_resource_group.Spoke_03.name
 dynamic "delegation" {
    for_each = each.key == "VnetIntegrationSubnet" ? [1] : []
    content{
        name = "appservice_delegation"
        service_delegation {
        name = "Microsoft.Web/serverFarms"
        actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
    }
    
  }
  depends_on = [ azurerm_virtual_network.Spoke_03_vnet ]
}
 
# Create an App Service Plan
resource "azurerm_app_service_plan" "plan" {
  name                = var.app_service_plan_name
  location            = azurerm_resource_group.Spoke_03.location
  resource_group_name = azurerm_resource_group.Spoke_03.name
  sku {
    tier = "Standard"
    size = "S1"
  }
  depends_on = [ azurerm_resource_group.Spoke_03 ]
}

# Create the Web App
resource "azurerm_app_service" "web_app" {
  name                = var.web_app_name
  location            = azurerm_resource_group.Spoke_03.location
  resource_group_name = azurerm_resource_group.Spoke_03.name
  app_service_plan_id = azurerm_app_service_plan.plan.id
  depends_on = [ azurerm_resource_group.Spoke_03 , azurerm_app_service_plan.plan ]
}

# Enable the Virtual Network Integration to App services
resource "azurerm_app_service_virtual_network_swift_connection" "vnet_integration" {
  app_service_id = azurerm_app_service.web_app.id
  subnet_id = azurerm_subnet.subnets["VnetIntegrationSubnet"].id
  depends_on = [ azurerm_app_service.web_app , azurerm_subnet.subnets ]
}

# Fetch the data from Hub Virtual Network for peering the Spoke_03 Virtual Network (Spoke_03 <--> Hub)
data "azurerm_virtual_network" "Hub_vnet" {
  name = "Hub_vnet"
  resource_group_name = "Hub_RG"
}

# Establish the Peering between Spoke_01 and Hub networks (Spoke_03 <--> Hub)
resource "azurerm_virtual_network_peering" "Spoke_03-To-Hub" {
  name                      = "Spoke_03-To-Hub"
  resource_group_name       = azurerm_virtual_network.Spoke_03_vnet["Spoke_03_vnet"].resource_group_name
  virtual_network_name      = azurerm_virtual_network.Spoke_03_vnet["Spoke_03_vnet"].name
  remote_virtual_network_id = data.azurerm_virtual_network.Hub_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.Spoke_03_vnet , data.azurerm_virtual_network.Hub_vnet  ]
}

# Establish the Peering between and Hub Spoke_01 networks (Hub <--> Spoke_03)
resource "azurerm_virtual_network_peering" "Hub-Spoke_03" {
  name                      = "Hub-Spoke_03"
  resource_group_name       = data.azurerm_virtual_network.Hub_vnet.resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.Hub_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.Spoke_03_vnet["Spoke_03_vnet"].id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = true
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.Spoke_03_vnet , data.azurerm_virtual_network.Hub_vnet ]
}
```

### Deployments in Portal :
![spoke03_portal](https://github.com/user-attachments/assets/08c80650-1e4d-41fe-9992-5f2b98f7c3a9)

### Resource Visualizer in Azure portal :
![sp3](https://github.com/user-attachments/assets/52aa902b-eafa-4531-a18b-ad349960a8f5)

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

- [azurerm_app_service.web_app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service) (resource)
- [azurerm_app_service_plan.plan](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_plan) (resource)
- [azurerm_app_service_virtual_network_swift_connection.vnet_integration](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_virtual_network_swift_connection) (resource)
- [azurerm_resource_group.Spoke_03](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_subnet.subnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_virtual_network.Spoke_03_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [azurerm_virtual_network_peering.Hub-Spoke_03](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) (resource)
- [azurerm_virtual_network_peering.Spoke_03-To-Hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) (resource)
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

The following input variables are optional (have default values):

### <a name="input_app_service_plan_name"></a> [app\_service\_plan\_name](#input\_app\_service\_plan\_name)

Description: n/a

Type: `string`

Default: `"The name of app service plan"`

### <a name="input_web_app_name"></a> [web\_app\_name](#input\_web\_app\_name)

Description: n/a

Type: `string`

Default: `"The name of web app name"`

## Outputs

The following outputs are exported:

### <a name="output_Spoke_03_RG"></a> [Spoke\_03\_RG](#output\_Spoke\_03\_RG)

Description: n/a

### <a name="output_app_plan"></a> [app\_plan](#output\_app\_plan)

Description: n/a

### <a name="output_web_app"></a> [web\_app](#output\_web\_app)

Description: n/a

## Modules

No modules.

This is the Spoke\_03 Network Configuration Terraform Files.
<!-- END_TF_DOCS -->