## Hub Network :
- 1.First we have to create the Resource Group for Hub.
- 2.We should create the Virtual Network for Hub with address space.
- 3.The Hub Virtual Network has multiple subnets with address prefixes.
- 4.We have to create the subnets for Firewall,VPN Gateway,Bastion and AppserviceSubnet.
- 5.Dedicated subnets : AzureFirewallSubnet, GatewaySubnet.
- 6.We should create the Local Network Gateway and Connection service for establish the connection between On_premises and Hub.

## Architecture Diagram :
![HUB](https://github.com/srinivasan2022/Project/assets/118502121/c8c76565-bee9-40d8-a214-fc10a26e259b)