<!-- BEGIN_TF_DOCS -->
## Spoke\_01 Network :
- 1.First we have to create the Resource Group for Spoke\_01.
- 2.We should create the Virtual Network for Spoke\_01 with address space.
- 3.The Spoke\_01 Virtual Network has multiple subnets with address prefixes.
- 4.Atleast one spoke must host a high-availability virtual machine(VM) service.
- 5.VM should have a shared drive mounted using Azure File Share.
- 6.We should create the Local Network Gateway and Connection service for establish the connection between Hub and On\_premises.
- 7.Each Network Security Group should associate with their respective Subnets.
- 8.We have to establish the peering between Hub and Spoke\_01.
- 9.We need to create the Azure Key valut service to store the VM username and password.

## Architecture Diagram :
![SPOKE\_01](https://github.com/user-attachments/assets/942a5d88-25fe-4b38-84ef-861488440f05)

```hcl
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

# Creates the Azure Key vault to store the VM username and password
resource "azurerm_key_vault" "Key_vault" {
  name                        = "MyKeyVault1603"
  resource_group_name = azurerm_resource_group.Spoke_01["Spoke_01_RG"].name
  location = azurerm_resource_group.Spoke_01["Spoke_01_RG"].location
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
  depends_on = [ azurerm_resource_group.Spoke_01 ]
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

# Create the Virtual Machines(VM) and assign the NIC to specific VMs
resource "azurerm_windows_virtual_machine" "VMs" {
  name                  = "${azurerm_subnet.subnets[local.nsg_names[each.key]].name}-VM"
  resource_group_name = azurerm_resource_group.Spoke_01["Spoke_01_RG"].name
  location = azurerm_resource_group.Spoke_01["Spoke_01_RG"].location
  size                  = "Standard_DS1_v2"
  # admin_username        =  azurerm_key_vault_secret.vm_admin_username.value  
  # admin_password        =  azurerm_key_vault_secret.vm_admin_password.value  
  admin_username = var.admin_username
  admin_password = var.admin_password
   for_each = {for idx , nic in azurerm_network_interface.subnet_nic : idx => nic.id}
  # for_each = local.NIC_Names
  network_interface_ids = [each.value]
  # zone = each.key
  

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
#   depends_on = [ azurerm_network_interface.subnet_nic ,  azurerm_storage_share.fileshare ]
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
resource "azurerm_storage_share" "fileshare" {
  name                 = "fileshare01"
  storage_account_name = azurerm_storage_account.storage-account.name
  quota                = 5
  depends_on = [ azurerm_resource_group.Spoke_01 , azurerm_storage_account.storage-account ]
}

# Mount the fileshare to Vitrual Machine
resource "azurerm_virtual_machine_extension" "your-extension" {
  name                 = "vm-extension-name"
  virtual_machine_id   = azurerm_windows_virtual_machine.VMs["Web-01"].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  protected_settings = <<SETTINGS
  {
   "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${local.base64EncodedScript }')) | Out-File -filepath postBuild.ps1\" && powershell -ExecutionPolicy Unrestricted -File postBuild.ps1"
  }
  SETTINGS

  depends_on = [azurerm_windows_virtual_machine.VMs]
}


# Create the data disk
resource "azurerm_managed_disk" "data_disk" {
  name                 = "vm-datadisk"
  resource_group_name = azurerm_resource_group.Spoke_01["Spoke_01_RG"].name
  location = azurerm_resource_group.Spoke_01["Spoke_01_RG"].location
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "4"
  depends_on = [ azurerm_windows_virtual_machine.VMs ]
}

# Attach the data disk to the virtual machine
resource "azurerm_virtual_machine_data_disk_attachment" "example_attach" {
  managed_disk_id    = azurerm_managed_disk.data_disk.id
  virtual_machine_id = azurerm_windows_virtual_machine.VMs["Web-01"].id
  lun                = 0
  caching            = "ReadWrite"
  depends_on = [ azurerm_windows_virtual_machine.VMs , azurerm_managed_disk.data_disk ]
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
  allow_gateway_transit     = true
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.Spoke_01_vnet , data.azurerm_virtual_network.Hub_vnet ]
}


# # Creates the policy definition
# resource "azurerm_policy_definition" "rg_policy_def" {
#   name         = "Spoke01_rg-policy"
#   policy_type  = "Custom"
#   mode         = "All"
#   display_name = "Spoke01 Policy"
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
#   name                 = "Spoke01-rg-policy-assignment"
#   policy_definition_id = azurerm_policy_definition.rg_policy_def.id
#   scope                = azurerm_resource_group.Spoke_01["Spoke_01_RG"].id
#   display_name         = "Spoke01_RG Policy Assignment"
#   description          = "Assigning policy to the resource group"
# }

# # Creates the Log Analytics workspace 
# resource "azurerm_log_analytics_workspace" "log_analytics" {
#   name                = "example-law"
#   resource_group_name = azurerm_resource_group.Spoke_01["Spoke_01_RG"].name
#   location = azurerm_resource_group.Spoke_01["Spoke_01_RG"].location
#   sku                 = "PerGB2018"
#   retention_in_days   = 10
# }

# # 
# resource "azurerm_monitor_diagnostic_setting" "vnet_monitor" {
#   name               = "diag-settings-vnet"
#   target_resource_id = azurerm_virtual_network.Spoke_01_vnet["Spoke_01_vnet"].id
#   log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics.id
 
#   log {
#     category = "NetworkSecurityGroupEvent"
#     enabled  = true
 
#     retention_policy {
#       enabled = false
#     }
#   }
# }
 
# resource "azurerm_monitor_diagnostic_setting" "vm_monitor" {
#   name               = "diag-settings-vm"
#   target_resource_id = azurerm_windows_virtual_machine.VMs[each.key].id
#   log_analytics_workspace_id = azurerm_log_analytics_workspace.example.id
 
#   log {
#     category = "GuestOSUpdate"
#     enabled  = true
 
#     retention_policy {
#       enabled = false
#     }
#   }
 
#   metric {
#     category = "AllMetrics"
#     enabled  = true
 
#     retention_policy {
#       enabled = false
#     }
#   }
# }


# # Create Recovery Services Vault
# resource "azurerm_recovery_services_vault" "vault" {
#   name                = "exampleRecoveryServicesVault"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
#   sku                 = "Standard"
# }
 
# # Create Backup Policy
# resource "azurerm_backup_policy_vm" "backup_policy" {
#   name                = "exampleBackupPolicy"
#   resource_group_name = azurerm_resource_group.rg.name
#   recovery_vault_name = azurerm_recovery_services_vault.vault.name
 
#   retention_daily {
#     count = 7
#   }
 
#   backup {
#     frequency = "Daily"
#     time      = "23:00"
#   }
# }
 
# # Enable Backup for VM
# resource "azurerm_backup_protected_vm" "protected_vm" {
#   resource_group_name    = azurerm_resource_group.rg.name
#   recovery_vault_name    = azurerm_recovery_services_vault.vault.name
#   source_vm_id           = azurerm_virtual_machine.vm.id
#   backup_policy_id       = azurerm_backup_policy_vm.backup_policy.id
# }
 
```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.1.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (~> 3.0.2)

## Providers

The following providers are used by this module:

- <a name="provider_azuread"></a> [azuread](#provider\_azuread)

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (~> 3.0.2)

## Resources

The following resources are used by this module:

- [azurerm_key_vault.Key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) (resource)
- [azurerm_key_vault_secret.vm_admin_password](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) (resource)
- [azurerm_key_vault_secret.vm_admin_username](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) (resource)
- [azurerm_managed_disk.data_disk](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/managed_disk) (resource)
- [azurerm_network_interface.subnet_nic](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) (resource)
- [azurerm_network_security_group.nsg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) (resource)
- [azurerm_resource_group.Spoke_01](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_storage_account.storage-account](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) (resource)
- [azurerm_storage_share.fileshare](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_share) (resource)
- [azurerm_subnet.subnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet_network_security_group_association.nsg_ass](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) (resource)
- [azurerm_virtual_machine_data_disk_attachment.example_attach](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_data_disk_attachment) (resource)
- [azurerm_virtual_machine_extension.your-extension](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_extension) (resource)
- [azurerm_virtual_network.Spoke_01_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [azurerm_virtual_network_peering.Hub-Spoke_01](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) (resource)
- [azurerm_virtual_network_peering.Spoke_01-To-Hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) (resource)
- [azurerm_windows_virtual_machine.VMs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine) (resource)
- [azuread_client_config.current](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/client_config) (data source)
- [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) (data source)
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
  "Spoke_01_RG": {
    "rg_location": "East us",
    "rg_name": "Spoke_01_RG"
  }
}
```

### <a name="input_rules_file"></a> [rules\_file](#input\_rules\_file)

Description: n/a

Type: `string`

Default: `"rules.csv"`

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
  "Web-01": {
    "address_prefix": "10.20.1.0/24",
    "subnet_name": "Web-01"
  },
  "Web-02": {
    "address_prefix": "10.20.2.0/24",
    "subnet_name": "Web-02"
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
  "Spoke_01_vnet": {
    "address_space": "10.20.0.0/16",
    "vnet_name": "Spoke_01_vnet"
  }
}
```

## Outputs

The following outputs are exported:

### <a name="output_NSG"></a> [NSG](#output\_NSG)

Description: n/a

### <a name="output_Spoke_01_RG"></a> [Spoke\_01\_RG](#output\_Spoke\_01\_RG)

Description: n/a

### <a name="output_Spoke_01_vnet"></a> [Spoke\_01\_vnet](#output\_Spoke\_01\_vnet)

Description: n/a

### <a name="output_VMs"></a> [VMs](#output\_VMs)

Description: n/a

### <a name="output_fileshare"></a> [fileshare](#output\_fileshare)

Description: n/a

### <a name="output_subnet_details"></a> [subnet\_details](#output\_subnet\_details)

Description: n/a

## Modules

No modules.

This is the Spoke\_01 Network Configuration Terraform Files.
<!-- END_TF_DOCS -->