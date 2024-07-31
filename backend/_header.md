### Terraform State Files :
## Steps :
1.First we should create the Resource Group.
2.We create the Azure Blob Storage account in resource group.
3.Finally we create the Storage account container to store the state files.
## Remote State Files

The terraform state file, by default, is named terraform. tfstate and is held in the same directory where Terraform is run. It is created after running terraform apply . The actual content of this file is a JSON formatted mapping of the resources defined in the configuration and those that exist in your infrastructure.

### State Files in Remote Stage : 

In Terraform, a remote state refers to storing the state file of your Terraform-managed infrastructure in a remote location instead of locally on your machine. This allows for better collaboration, security, and state management in larger or team-based projects.
- Storage Options: Remote state can be stored in various backend services such as Amazon S3, Google Cloud Storage, Azure Blob Storage, Terraform Cloud, etc.
- Collaboration: By storing the state remotely, multiple team members can access and update the state file, ensuring that everyone is working with the most current state.
- Security: Remote backends can offer additional security features such as encryption and access control.
- Configuration: To use a remote state, you need to configure the backend block in your Terraform configuration file.

### Configuration :
```hcl
  backend "azurerm" {
    resource_group_name  = "Project_TF_RemoteState_RG"   // TF State - Resource Group
    storage_account_name = "projectremotestatestacc"    // TF State - Storage account 
    container_name       = "project-state-files"       // TF State - storage account container
    key                  = "project.tfstate"              // TF State - Files
  }
```