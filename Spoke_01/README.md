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
![SPOKE\_01](https://github.com/user-attachments/assets/d7a7fa0b-6fda-4bc4-b399-f1c2347abeb4)

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
# Create the Resource Group
resource "azurerm_resource_group" "Spoke_01" {
   name     = var.rg_name
   location = var.rg_location
}

# Create the Virtual Network with address space
resource "azurerm_virtual_network" "Spoke_01_vnet" {
    for_each = var.vnet_details
    name = each.value.vnet_name
    address_space = [each.value.address_space]
    resource_group_name = azurerm_resource_group.Spoke_01.name
    location = azurerm_resource_group.Spoke_01.location
    depends_on = [ azurerm_resource_group.Spoke_01 ]
}

# Create the Subnets with address prefixes
resource "azurerm_subnet" "subnets" {
  for_each = var.subnet_details
  name = each.key
  address_prefixes = [each.value.address_prefix]
  virtual_network_name = azurerm_virtual_network.Spoke_01_vnet["Spoke_01_vnet"].name
  resource_group_name = azurerm_resource_group.Spoke_01.name
  depends_on = [ azurerm_virtual_network.Spoke_01_vnet ]
}

# Create the Network Security Group with Rules
resource "azurerm_network_security_group" "nsg" {
  for_each = toset(local.subnet_names)
  name = each.key
  resource_group_name = azurerm_resource_group.Spoke_01.name
  location = azurerm_resource_group.Spoke_01.location

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
  resource_group_name = azurerm_resource_group.Spoke_01.name
  location = azurerm_resource_group.Spoke_01.location
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnets[local.nsg_names[each.key]].id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [ azurerm_virtual_network.Spoke_01_vnet , azurerm_subnet.subnets ]
}

# Fetch the data from key vault
data "azurerm_key_vault" "Key_vault" {
  name                = "AzMyKeyVault160322"
  resource_group_name = "On_Premises_RG"
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

# Create the Virtual Machines(VM) and assign the NIC to specific VMs
resource "azurerm_windows_virtual_machine" "VMs" {
  name                  = "${azurerm_subnet.subnets[local.nsg_names[each.key]].name}-VM"
  resource_group_name = azurerm_resource_group.Spoke_01.name
  location = azurerm_resource_group.Spoke_01.location
  size                  = "Standard_DS1_v2"
   admin_username        =  data.azurerm_key_vault_secret.vm_admin_username.value  
   admin_password        =  data.azurerm_key_vault_secret.vm_admin_password.value  
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
   depends_on = [ azurerm_network_interface.subnet_nic ,  data.azurerm_key_vault_secret.vm_admin_username , data.azurerm_key_vault_secret.vm_admin_password ]
 }

# Create the Storage account for FileShare
resource "azurerm_storage_account" "storage-account" {
  name                     = var.storage_account_name
  resource_group_name =     azurerm_resource_group.Spoke_01.name
  location                 = azurerm_resource_group.Spoke_01.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  depends_on = [ azurerm_resource_group.Spoke_01  ]
}
 
# Create the FileShare in Storage account
resource "azurerm_storage_share" "fileshare" {
  name                 = var.file_share_name
  storage_account_name = azurerm_storage_account.storage-account.name
  quota                = 5
  depends_on = [ azurerm_resource_group.Spoke_01 , azurerm_storage_account.storage-account ]
}

# Create the data disk
resource "azurerm_managed_disk" "data_disk" {
  name                 = var.data_disk_name
  resource_group_name = azurerm_resource_group.Spoke_01.name
  location = azurerm_resource_group.Spoke_01.location
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

resource "local_file" "mount_file_share" {
  filename = "${path.module}/mount-fileshare.ps1" # Path to save the script

  content = <<-EOF
   $storageAccountName = "${azurerm_storage_account.storage-account.name}"
  $shareName = "${azurerm_storage_share.fileshare.name}"
  $storageAccountKey = "${azurerm_storage_account.storage-account.primary_access_key}"

  # Mount point for the file share
  \$mountPoint = "Z:"

  # Create the credential object
  \$user = "\$storageAccountName"
  \$pass = ConvertTo-SecureString -String "\$storageAccountKey" -AsPlainText -Force
  \$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList \$user, \$pass

  # Mount the file share
  New-PSDrive -Name \$mountPoint.Substring(0, 1) -PSProvider FileSystem -Root "\\\\\$storageAccountName.file.core.windows.net\\\$shareName" -Credential \$credential -Persist

  # Ensure the drive is mounted at startup
  \$script = "New-PSDrive -Name \$(\$mountPoint.Substring(0, 1)) -PSProvider FileSystem -Root '\\\\\$storageAccountName.file.core.windows.net\\\$shareName' -Credential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList \$user, \$pass) -Persist"
  \$scriptBlock = [scriptblock]::Create(\$script)
  Set-Content -Path C:\\mount-fileshare.ps1 -Value \$scriptBlock
  EOF
  depends_on = [ azurerm_windows_virtual_machine.VMs , azurerm_storage_share.fileshare ]
}


# Create Recovery Services Vault
resource "azurerm_recovery_services_vault" "vault" {
  name                = "RecoveryServicesVault001"
  location            = azurerm_resource_group.Spoke_01.location
  resource_group_name = azurerm_resource_group.Spoke_01.name
  sku                 = "Standard"
}
 
# Create Backup Policy
resource "azurerm_backup_policy_vm" "backup_policy" {
  name                = "VmBackupPolicy"
  resource_group_name = azurerm_resource_group.Spoke_01.name
  recovery_vault_name = azurerm_recovery_services_vault.vault.name
 
  retention_daily {
    count = 7
  }
 
  backup {
    frequency = "Daily"
    time      = "23:00"
  }
}

# Enable Backup for VM
resource "azurerm_backup_protected_vm" "protected_vm" {
  for_each = azurerm_windows_virtual_machine.VMs
  resource_group_name    = azurerm_resource_group.Spoke_01.name
  recovery_vault_name    = azurerm_recovery_services_vault.vault.name
  source_vm_id           = each.key.id
  backup_policy_id       = azurerm_backup_policy_vm.backup_policy.id
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

- <a name="provider_local"></a> [local](#provider\_local)

## Resources

The following resources are used by this module:

- [azurerm_backup_policy_vm.backup_policy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/backup_policy_vm) (resource)
- [azurerm_backup_protected_vm.protected_vm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/backup_protected_vm) (resource)
- [azurerm_managed_disk.data_disk](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/managed_disk) (resource)
- [azurerm_network_interface.subnet_nic](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) (resource)
- [azurerm_network_security_group.nsg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) (resource)
- [azurerm_recovery_services_vault.vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/recovery_services_vault) (resource)
- [azurerm_resource_group.Spoke_01](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_storage_account.storage-account](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) (resource)
- [azurerm_storage_share.fileshare](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_share) (resource)
- [azurerm_subnet.subnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet_network_security_group_association.nsg_ass](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) (resource)
- [azurerm_virtual_machine_data_disk_attachment.example_attach](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_data_disk_attachment) (resource)
- [azurerm_virtual_network.Spoke_01_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [azurerm_virtual_network_peering.Hub-Spoke_01](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) (resource)
- [azurerm_virtual_network_peering.Spoke_01-To-Hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) (resource)
- [azurerm_windows_virtual_machine.VMs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine) (resource)
- [local_file.mount_file_share](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) (resource)
- [azurerm_key_vault.Key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) (data source)
- [azurerm_key_vault_secret.vm_admin_password](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) (data source)
- [azurerm_key_vault_secret.vm_admin_username](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) (data source)
- [azurerm_virtual_network.Hub_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_data_disk_name"></a> [data\_disk\_name](#input\_data\_disk\_name)

Description: The name of Data disk name

Type: `string`

### <a name="input_file_share_name"></a> [file\_share\_name](#input\_file\_share\_name)

Description: The name of file share name

Type: `string`

### <a name="input_rg_location"></a> [rg\_location](#input\_rg\_location)

Description: The Location of the Resource Group

Type: `string`

### <a name="input_rg_name"></a> [rg\_name](#input\_rg\_name)

Description: The name of the Resource Group

Type: `string`

### <a name="input_storage_account_name"></a> [storage\_account\_name](#input\_storage\_account\_name)

Description: The name of storage account name

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

### <a name="input_rules_file"></a> [rules\_file](#input\_rules\_file)

Description: The name of CSV file containing NSG rules

Type: `string`

Default: `"rules.csv"`

## Outputs

The following outputs are exported:

### <a name="output_NSG"></a> [NSG](#output\_NSG)

Description: n/a

### <a name="output_Spoke_01_RG"></a> [Spoke\_01\_RG](#output\_Spoke\_01\_RG)

Description: n/a

### <a name="output_Spoke_01_vnet"></a> [Spoke\_01\_vnet](#output\_Spoke\_01\_vnet)

Description: n/a

### <a name="output_fileshare"></a> [fileshare](#output\_fileshare)

Description: n/a

### <a name="output_subnet_details"></a> [subnet\_details](#output\_subnet\_details)

Description: n/a

## Modules

No modules.

This is the Spoke\_01 Network Configuration Terraform Files.
<!-- END_TF_DOCS -->