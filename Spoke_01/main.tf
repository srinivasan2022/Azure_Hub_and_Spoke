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
 