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

# Create the Availability Set for High availability
resource "azurerm_availability_set" "av-set" {
  name                = "av-set"
  resource_group_name = azurerm_resource_group.Spoke_01["Spoke_01_RG"].name
  location = azurerm_resource_group.Spoke_01["Spoke_01_RG"].location
 
  managed            = true
  platform_fault_domain_count = 2
  platform_update_domain_count = 2
  depends_on = [ azurerm_resource_group.Spoke_01 ]
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
    ]
  }
  depends_on = [ azurerm_resource_group.Spoke_01 ]
}

# Creates the Azure Key vault secret to store the VM username and password
resource "azurerm_key_vault_secret" "vm_admin_username" {
  name         = "Spokevirtualmachineusername"
  value        = var.admin_username
  key_vault_id = azurerm_key_vault.Key_vault.id
  depends_on = [ azurerm_key_vault.Key_vault ]
}

# Creates the Azure Key vault secret to store the VM username and password
resource "azurerm_key_vault_secret" "vm_admin_password" {
  name         = "Spokevirtualmachinepassword"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.Key_vault.id
  depends_on = [ azurerm_key_vault.Key_vault ]
}

# Create the Virtual Machines(VM) in Availability Set and assign the NIC to specific VMs
resource "azurerm_windows_virtual_machine" "VMs" {
  name                  = "${azurerm_subnet.subnets[local.nsg_names[each.key]].name}-VM"
  resource_group_name = azurerm_resource_group.Spoke_01["Spoke_01_RG"].name
  location = azurerm_resource_group.Spoke_01["Spoke_01_RG"].location
  size                  = "Standard_DS1_v2"
  admin_username        =  azurerm_key_vault_secret.vm_admin_username.value  
  admin_password        =  azurerm_key_vault_secret.vm_admin_password.value  
  for_each = {for idx , nic in azurerm_network_interface.subnet_nic : idx => nic.id}
  network_interface_ids = [each.value]
   availability_set_id =azurerm_availability_set.av-set.id

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
  depends_on = [ azurerm_network_interface.subnet_nic ]
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
 
# # Create the FileShare in Storage account
# resource "azurerm_storage_share" "fileshare" {
#   name                 = "fileshare01"
#   storage_account_name = azurerm_storage_account.storage-account.name
#   quota                = 5
#   depends_on = [ azurerm_resource_group.Spoke_01 , azurerm_storage_account.storage-account ]
# }

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
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on = [ azurerm_virtual_network.Spoke_01_vnet , data.azurerm_virtual_network.Hub_vnet ]
}

resource "azurerm_route_table" "route_table" {
  name                = "Spoke01-route-table"
  resource_group_name = azurerm_resource_group.Spoke_01["Spoke_01_RG"].name
  location = azurerm_resource_group.Spoke_01["Spoke_01_RG"].location
  depends_on = [ azurerm_resource_group.Spoke_01 , azurerm_subnet.subnets ]
}

# Creates the route in the route table (Spoke01-NVA-Spoke02)
resource "azurerm_route" "route_02" {
  name                   = "ToSpoke02"
  resource_group_name = azurerm_resource_group.Spoke_01["Spoke_01_RG"].name
  route_table_name = azurerm_route_table.route_table.name
  address_prefix = "10.30.0.0/16"     # destnation network address space
  next_hop_type          = "VirtualAppliance" 
  next_hop_in_ip_address = "10.10.4.4"   # NVA private IP
  depends_on = [ azurerm_route_table.route_table ]
}

# Creates the route in the route tables (Spoke01-To-Firewall)
resource "azurerm_route" "route_03" {
  name                   = "ToFirewall"
  resource_group_name = azurerm_resource_group.Spoke_01["Spoke_01_RG"].name
  route_table_name = azurerm_route_table.route_table.name
  address_prefix         = "0.0.0.0/0"     # All Traffic
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = "10.10.0.4"     # Firewall private IP
  depends_on = [ azurerm_route_table.route_table ]
}

# Associate the route table with the subnet
resource "azurerm_subnet_route_table_association" "example" {
   subnet_id                 = azurerm_subnet.subnets["Web"].id
  route_table_id = azurerm_route_table.route_table.id
  depends_on = [ azurerm_subnet.subnets , azurerm_route_table.route_table ]
}

# # Creates the Routes in the route tables
# resource "azurerm_route" "route_01" {
#   name                   = "route-01"
#   resource_group_name = azurerm_resource_group.Spoke_01["Spoke_01_RG"].name
#   for_each = toset(local.subnet_names)
#   route_table_name = azurerm_route_table.route_table[each.key].name
#   address_prefix         = "0.0.0.0/0"
#   next_hop_type          = "Internet"
#   depends_on = [ azurerm_route_table.route_table ]
# }

# # Another route in the route table (example)
# resource "azurerm_route" "route_02" {
#   name                   = "route-02"
#   resource_group_name = azurerm_resource_group.Spoke_01["Spoke_01_RG"].name
#   for_each = toset(local.subnet_names)
#   route_table_name = azurerm_route_table.route_table[each.key].name
#   address_prefix = "10.30.0.0/16"    // destination vnet ip
#   next_hop_type          = "VirtualAppliance"  //type
#   next_hop_in_ip_address = "10.10.4.4"   // nva ip
# }

# # Associate the route table with the subnet
# resource "azurerm_subnet_route_table_association" "example" {
#   for_each = { for idx , subnet in azurerm_subnet.subnets : idx => subnet.id}
#    subnet_id                 = each.value
#   route_table_id = azurerm_route_table.route_table[local.nsg_names[each.key]].id//[for udr in azurerm_route_table.route_table : udr.id]
#   depends_on = [ azurerm_subnet.subnets , azurerm_route_table.route_table ]
# }

# resource "azurerm_virtual_machine_extension" "vm_extension" {
#   //for_each = [for vm in azurerm_windows_virtual_machine.VMs : vm.name]
#   name                 = "${azurerm_windows_virtual_machine.VMs["Web"].name}-extension"
#   virtual_machine_id   = azurerm_windows_virtual_machine.VMs["Web"].id
#   publisher            = "Microsoft.Compute"
#   type                 = "CustomScriptExtension"
#   type_handler_version = "1.10"

#   settings = <<SETTINGS
#     {
#         "commandToExecute": "powershell -ExecutionPolicy Unrestricted -Command \\"$acctName = '${azurerm_storage_account.storage-account.name}'; $acctKey = '${azurerm_storage_account.storage-account.primary_access_key}'; net use Z: \\\\'${azurerm_storage_account.storage-account.name}.file.core.windows.net\\${azurerm_storage_share.fileshare.name} /user:$acctName $acctKey\\""
#     }
#   SETTINGS
# }

# resource "azurerm_virtual_machine_extension" "vm_extension" {
#   name                 = "${azurerm_windows_virtual_machine.VMs["Web"].name}-extension"
#   virtual_machine_id =   azurerm_windows_virtual_machine.VMs["Web"].id
#   publisher            = "Microsoft.Azure.Extensions"
#   type                 = "CustomScript"
#   type_handler_version = "2.0"
 
#   settings = <<SETTINGS
#     {
#    "commandToExecute": "apt-get update && apt-get install -y cifs-utils && mkdir -p /mnt/fileshare && mount -t cifs //${azurerm_storage_account.storage-account.name}.file.core.windows.net/${azurerm_storage_share.fileshare.name} /mnt/fileshare -o vers=3.0,username=${azurerm_storage_account.storage-account.name},password=${azurerm_storage_account.storage-account.primary_access_key},dir_mode=0777,file_mode=0777,serverino"
#     }
#   SETTINGS
# }


# resource "azurerm_virtual_machine_extension" "example" {
#   name                 = "${azurerm_windows_virtual_machine.VMs["Web"].name}-extension"
#   virtual_machine_id   = azurerm_windows_virtual_machine.VMs["Web"].id
#   publisher            = "Microsoft.Compute"
#   type                 = "CustomScriptExtension"
#   type_handler_version = "1.10"

#   settings = <<SETTINGS
#     {
#         "fileUris": ["https://<your-storage-account-name>.blob.core.windows.net/scripts/mount-fileshare.ps1"],
#         "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File mount-fileshare.ps1"
#     }
# SETTINGS

#   protected_settings = <<PROTECTED_SETTINGS
#     {
#         "storageAccountName": "${azurerm_storage_account.storage-account.name}",
#         "storageAccountKey": "${azurerm_storage_account.storage-account.primary_access_key}"
#     }
# PROTECTED_SETTINGS
# }

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
 