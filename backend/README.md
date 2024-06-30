<!-- BEGIN_TF_DOCS -->


```hcl
# Create the Resource Group
resource "azurerm_resource_group" "rg" {
  name = var.resource_group_name
  location = var.location
}

# Create the Storage Account
resource "azurerm_storage_account" "storageaccount" {
  name = var.storage_account_name
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  account_tier = "Standard"
  account_replication_type = "LRS"
  depends_on = [ azurerm_resource_group.rg ]
}

# Create the Storage Account Container to store the state files
resource "azurerm_storage_container" "project_state" {
  name = "project-state-files"
  storage_account_name = azurerm_storage_account.storageaccount.name
  container_access_type = "private"
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

- [azurerm_resource_group.rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_storage_account.storageaccount](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) (resource)
- [azurerm_storage_container.project_state](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) (resource)

<!-- markdownlint-disable MD013 -->
## Required Inputs

No required inputs.

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_location"></a> [location](#input\_location)

Description: The region in which the resources will be deployed

Type: `string`

Default: `"east us"`

### <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name)

Description: The name of the resource group

Type: `string`

Default: `"Project_TF_RemoteState_RG"`

### <a name="input_storage_account_name"></a> [storage\_account\_name](#input\_storage\_account\_name)

Description: The name of the storage account

Type: `string`

Default: `"projectremotestatestacc"`

## Outputs

No outputs.

## Modules

No modules.

<!-- END_TF_DOCS -->