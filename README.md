# Project

## Requirements :

- 1.We need to create the On_Premises , Hub , Spoke_01 , Spoke_02 , Spoke_03 networks.
- 2.Hub is the central point of connectivity between Hub and Spoke networks.
- 3.The On_premises network establish the connection to Hub network through the internet using VPN Gateway (S2S).
- 4.The Spoke_01 network establish the connection to Hub network by VNET Peering.
- 5.The Spoke_02 network establish the connection to Hub network by VNET Peering.
- 6.The Spoke_01 should communicates Spoke_02 through Hub network. 
- 7.All VMs must have daily backups enabled. 
- 8.Regional replication must be enabled for all VM backups to ensure data redundancy. 
- 9.All Azure Policies should be scoped to the Resource Group level. 
- 10.All VMs should remain private, without public IP addresses.
- 11.All logs should go to Log Analytic workspace.

## Architecture Diagram :
![Overall](https://github.com/srinivasan2022/Project/assets/118502121/72d5a2f6-0f7b-4d58-a511-72a846aba13a)

### 1.On_Premises network :

It refers to Cloud-based services. However, Azure can work with your On_Premise infrastructure. On_premises refers to your own physical servers and data storage located within your own facilities. Azure offers tools like data gateways to connect your On_Premise resources to Azure cloud services for a hybrid approach.

### 2.Hub and Spoke network :

The hub is a virtual network in Azure that acts a a central point of connectivity to your On_Premises network. The Spokes are virtual networks that peer with the hub and can be used to isolate workloads. Traffic flows between the On_Premises data center(s) and hub through an ExpressRoute or VPN gateway connection.

### 3.Virtual Network Peering :

Virtual network peering enables you to seamlessly connect two or more Virtual Networks in Azure. The virtual networks appear as one for connectivity purposes. The traffic between virtual machines in peered virtual networks uses the Microsoft backbone infrastructure.This enables direct, high-bandwidth communication between VNets without the need for gateways, resulting in low-latency, high-speed network connections.
#### Virtual network peering : 
Connecting virtual networks within the same Azure region.
#### Global virtual network peering : 
Connecting virtual networks across Azure regions.

### 4.Site-to-Site (S2S) :
A Site-to-Site VPN gateway connection is used to connect your on-premises network to an Azure virtual network over an IPsec/IKE (IKEv1 or IKEv2) VPN tunnel. This type of connection requires a VPN device located on-premises that has an externally facing public IP address assigned to it.
