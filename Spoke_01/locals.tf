locals {
     rules_csv = csvdecode(file(var.rules_file))

    subnet_names = [for subnet in azurerm_subnet.subnets : subnet.name]
    
    nsg_names = { for idx , nsg in azurerm_network_security_group.nsg : idx => nsg.name}

    //NIC_names =  { for idx , nic in azurerm_network_interface.subnet_nic : idx => nic.name }
    //VM_name = {for idx , vm in azurerm_windows_virtual_machine.VMs : idx => vm.name}
    //nic_names = [for i in azurerm_network_interface.subnet_nic : i.id]
    #  NIC_names =  { for idx , nic in azurerm_network_interface.subnet_nic : idx => nic.name }
    #   NIC_Names = {
    #    1 = local.NIC_names["Web-01"]
    #    2 = local.NIC_names["Web-02"]
    # }

   yourPowerShellScript= try(file("scripts/mount-fileshare.ps1"), null)
   base64EncodedScript = base64encode(local.yourPowerShellScript)

}