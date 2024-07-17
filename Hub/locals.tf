locals {
     subnet_names = [for subnet in azurerm_subnet.subnets : subnet.name]
     //subnet_names = compact([for subnet in azurerm_subnet.subnets : subnet.name if subnet.name != "NVASubnet"])
     # I have Public IP's for Firewall , VPN Gateway and Bastion but I dont have Public IP for NVASubnet .
     # That's why , I ignore the NVASubnet using compact function.
}