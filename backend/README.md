<!-- BEGIN_TF_DOCS -->
### Terraform State Files :
## Steps :
1.First we should create the Resource Group.
2.We create the Azure Blob Storage account in resource group.
3.Finally we create the Storage account container to store the state files.

## Architecture diagram :
![statefile](https://github.com/user-attachments/assets/d3abe75b-4b74-496a-8dd5-7fa6e2378731)

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
### Configuration :
```hcl
  backend "azurerm" {
    resource_group_name  = "Project_TF_RemoteState_RG"   // TF State - Resource Group
    storage_account_name = "projectremotestatestacc"    // TF State - Storage account
    container_name       = "project-state-files"       // TF State - storage account container
    key                  = "project.tfstate"              // TF State - Files
  }
```

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
  name = var.container_name
  storage_account_name = azurerm_storage_account.storageaccount.name
  container_access_type = "private"
}
 
```
### Screenshot :

![backend](https://github.com/user-attachments/assets/d4198f04-f8e0-4a2f-8f54-3f3591d401ba)


## Remote State Files

The terraform state file, by default, is named terraform. tfstate and is held in the same directory where Terraform is run. It is created after running terraform apply . The actual content of this file is a JSON formatted mapping of the resources defined in the configuration and those that exist in your infrastructure.

### State Files in Remote Stage :

In Terraform, a remote state refers to storing the state file of your Terraform-managed infrastructure in a remote location instead of locally on your machine. This allows for better collaboration, security, and state management in larger or team-based projects.
- Storage Options: Remote state can be stored in various backend services such as Amazon S3, Google Cloud Storage, Azure Blob Storage, Terraform Cloud, etc.
- Collaboration: By storing the state remotely, multiple team members can access and update the state file, ensuring that everyone is working with the most current state.
- Security: Remote backends can offer additional security features such as encryption and access control.
- Configuration: To use a remote state, you need to configure the backend block in your Terraform configuration file.


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

The following input variables are required:

### <a name="input_container_name"></a> [container\_name](#input\_container\_name)

Description: The name of the storage account container

Type: `string`

### <a name="input_location"></a> [location](#input\_location)

Description: The region in which the resources will be deployed

Type: `string`

### <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name)

Description: The name of the resource group

Type: `string`

### <a name="input_storage_account_name"></a> [storage\_account\_name](#input\_storage\_account\_name)

Description: The name of the storage account

Type: `string`

## Optional Inputs

No optional inputs.

## Outputs

No outputs.

## Modules

No modules.

<!-- END_TF_DOCS -->