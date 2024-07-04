locals {
     subnet_names = [for subnet in azurerm_subnet.subnets : subnet.name]
     //subnet_names = compact([for subnet in azurerm_subnet.subnets : subnet.name if subnet.name != "AppServiceSubnet"])
     # I have Public IP's for Firewall , VPN Gateway and Bastion but I dont have Public IP for AppServiceSubnet .
     # That's why , I ignore the AppserviceSubnet using compact function.
}