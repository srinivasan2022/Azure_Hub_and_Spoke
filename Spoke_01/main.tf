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
  name                = "MyKeyVault160322"
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

# #Creates the private endpoint
# resource "azurerm_private_endpoint" "storage_endpoint" {
#   name = var.private_endpoint_name
#   resource_group_name = azurerm_storage_account.storage-account.resource_group_name
#   location = azurerm_storage_account.storage-account.location
#   subnet_id = azurerm_subnet.subnets["Web-01"].id
#   private_service_connection {
#     name = "storage_privatelink"
#     private_connection_resource_id = azurerm_storage_account.storage-account.id
#     subresource_names = [ "file" ]
#     is_manual_connection = false
#   }
#   depends_on = [ azurerm_subnet.subnets , azurerm_storage_account.storage-account , azurerm_storage_share.fileshare ]
# }

# # Creates the private DNS zone
# resource "azurerm_private_dns_zone" "pr_dns_zone" {
#   name = var.private_dns_zone_name
#   resource_group_name = azurerm_resource_group.Spoke_01.name
#   depends_on = [ azurerm_resource_group.Spoke_01 ]
# }

# # Creates the virtual network link in private DNS zone
# resource "azurerm_private_dns_zone_virtual_network_link" "vnet_link" {
#   name = var.private_dns_zone_vnet_link
#   resource_group_name = azurerm_private_dns_zone.pr_dns_zone.resource_group_name
#   private_dns_zone_name = azurerm_private_dns_zone.pr_dns_zone.name
#   virtual_network_id = data.azurerm_virtual_network.Hub_vnet.id     # Creates the link to Hub vnet
#   #virtual_network_id = azurerm_virtual_network.Spoke_01_vnet["Spoke_01_vnet"].id
#   depends_on = [ azurerm_private_dns_zone.pr_dns_zone , data.azurerm_virtual_network.Hub_vnet ]
# }

# # Creates the records in private DNS zone
# resource "azurerm_private_dns_a_record" "dns_record" {
#   name = var.private_dns_a_record
#   zone_name = azurerm_private_dns_zone.pr_dns_zone.name
#   resource_group_name = azurerm_private_dns_zone.pr_dns_zone.resource_group_name
#   ttl = 300
#   records = [ azurerm_private_endpoint.storage_endpoint.private_service_connection[0].private_ip_address ]
#   depends_on = [ azurerm_private_dns_zone.pr_dns_zone , azurerm_private_endpoint.storage_endpoint  ]
# }


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
#   resource_group_name = azurerm_resource_group.Spoke_01.name
#   location = azurerm_resource_group.Spoke_01.location
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
 