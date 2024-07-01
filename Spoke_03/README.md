<!-- BEGIN_TF_DOCS -->
## Spoke\_03 Network :
- 1.First we have to create the Resource Group for Spoke\_03.
- 2.Then, we create the app service plan for app services.
- 3.Finally we create the app services in their app services plan.

## Architecture Diagram :
![SPOKE\_03](https://github.com/srinivasan2022/Project/assets/118502121/9eb15f28-eb35-420d-b7a1-7c2ed4275468)

```hcl
# Create a resource group
resource "azurerm_resource_group" "Spoke_03" {
  for_each = var.rg_details
  name     = each.value.rg_name
  location = each.value.rg_location
}
 
# Create an App Service Plan
resource "azurerm_app_service_plan" "plan" {
  name                = "appserviceplan"
  location            = azurerm_resource_group.Spoke_03["Spoke_03_RG"].location
  resource_group_name = azurerm_resource_group.Spoke_03["Spoke_03_RG"].name
  sku {
    tier = "Standard"
    size = "S1"
  }
  depends_on = [ azurerm_resource_group.Spoke_03 ]
}

# Create the Web App
resource "azurerm_app_service" "web_app" {
  name                = "my-webapp1603"
  location            = azurerm_resource_group.Spoke_03["Spoke_03_RG"].location
  resource_group_name = azurerm_resource_group.Spoke_03["Spoke_03_RG"].name
  app_service_plan_id = azurerm_app_service_plan.plan.id

  # site_config {
  #   dotnet_framework_version = "v4.0"
  # }

  # app_settings = {
  #   "WEBSITE_RUN_FROM_PACKAGE" = "1"
  # }

  # identity {
  #   type = "SystemAssigned"
  # }
  depends_on = [ azurerm_resource_group.Spoke_03 , azurerm_app_service_plan.plan ]
}

# Fetch the Subnet details from Spoke_01 Network
data "azurerm_subnet" "app_subnet" {
  name = "App"
  resource_group_name = "Spoke_01_RG"
  virtual_network_name = "Spoke_01_vnet"
}

# Enable the Virtual Network Integration to App services
resource "azurerm_app_service_virtual_network_swift_connection" "example" {
  app_service_id = azurerm_app_service.web_app.id
  subnet_id = data.azurerm_subnet.app_subnet.id
  depends_on = [ azurerm_app_service.web_app , data.azurerm_subnet.app_subnet ]
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

- [azurerm_app_service.web_app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service) (resource)
- [azurerm_app_service_plan.plan](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_plan) (resource)
- [azurerm_app_service_virtual_network_swift_connection.example](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_virtual_network_swift_connection) (resource)
- [azurerm_resource_group.Spoke_03](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_subnet.app_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

No required inputs.

## Optional Inputs

The following input variables are optional (have default values):

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
  "Spoke_03_RG": {
    "rg_location": "East us",
    "rg_name": "Spoke_03_RG"
  }
}
```

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