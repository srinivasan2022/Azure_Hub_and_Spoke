# Hub-spoke network topology in Azure :

[![Documentation](https://img.shields.io/badge/Azure-blue?style=for-the-badge)](https://azure.microsoft.com/en-us/resources/cloud-computing-dictionary/what-is-azure) [![Documentation](https://img.shields.io/badge/Azure_Virtual_Network-blue?style=for-the-badge)](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview) [![Documentation](https://img.shields.io/badge/Azure_Firewall-blue?style=for-the-badge)](https://learn.microsoft.com/en-us/azure/firewall/overview) [![Documentation](https://img.shields.io/badge/Azure_Bastion-blue?style=for-the-badge)](https://learn.microsoft.com/en-us/azure/bastion/bastion-overview) [![Documentation](https://img.shields.io/badge/Azure_VPN_Gateway-blue?style=for-the-badge)](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways) 

#### Description :
This project will implement an Azure [Hub and Spoke](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/hub-spoke-network-topology) architecture to support a student details application, focusing on security and efficiency. This architecture will feature a centralized hub for shared resources and multiple spoke networks for isolated environments, ensuring high availability and resiliency. Key elements include guard rails to enforce governance, robust security measures including encryption and firewalls, and comprehensive monitoring and logging capabilities. The solution will also incorporate backup and recovery strategies to protect data integrity and ensure business continuity. 


#### Steps :
<mark>NOTE : First we have to create the backend file for storing the state files.</mark>
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
<img src="Images/Overall.png" align="center">


### Workflow :
This hub-spoke network configuration uses the following architectural elements:

**Hub virtual network:**  The hub [virtual network](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview) hosts shared Azure services. Workloads hosted in the spoke virtual networks can use these services. The hub virtual network is the central point of connectivity for cross-premises networks.

**Spoke virtual networks:** Spoke virtual networks isolate and manage workloads separately in each spoke. Each workload can include multiple tiers, with multiple subnets connected through Azure load balancers. Spokes can exist in different subscriptions and represent different environments, such as Production and Non-production.

**Virtual network connectivity:** This architecture connects virtual networks by using [virtual network peering](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview) connections or connected groups. Peering connections and connected groups are non-transitive, low-latency connections between virtual networks. Peered or connected virtual networks can exchange traffic over the Azure backbone without needing a router. Azure Virtual Network Manager creates and manages network groups and their connections.

**Azure Bastion host:** Azure Bastion provides secure connectivity from the Azure portal to virtual machines (VMs) by using your browser. An Azure Bastion host deployed inside an Azure virtual network can access VMs in that virtual network or in connected virtual networks.

**Azure VPN Gateway or Azure ExpressRoute gateway:** A virtual network gateway enables a virtual network to connect to a virtual private network (VPN) device or Azure ExpressRoute circuit. The gateway provides cross-premises network connectivity. For more information, see [Connect an on-premises network to a Microsoft Azure virtual network](https://learn.microsoft.com/en-us/microsoft-365/enterprise/connect-an-on-premises-network-to-a-microsoft-azure-virtual-network?view=o365-worldwide) and Extend an on-premises network using VPN.

**Azure Firewall:** An Azure Firewall managed firewall instance exists in its own subnet.

### Components:
<img src="https://www.checkpoint.com/wp-content/uploads/microsoft-azure-virtual-networks-vnet.png" width="60px" align="right">

**[Virtual Network:](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview)** Azure Virtual Network is the fundamental building block for private networks in Azure. Virtual Network enables many Azure resources, such as Azure VMs, to securely communicate with each other, cross-premises networks, and the internet.

<img src="https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQf1tfUKFwY2aEQVeePMozBGvVWZvuU8HtEbw&s" width="80px" align="right">

**[Azure Firewall:](https://learn.microsoft.com/en-us/azure/firewall/overview)** Azure Firewall is a managed cloud-based network security service that protects Virtual Network resources. This stateful firewall service has built-in high availability and unrestricted cloud scalability to help you create, enforce, and log application and network connectivity policies across subscriptions and virtual networks.

<img src="https://azure.microsoft.com/svghandler/vpn-gateway/?width=600&height=315" width="80px" align="right">

**[VPN Gateway:](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways)** VPN Gateway is a specific type of virtual network gateway that sends encrypted traffic between a virtual network and an on-premises location over the public internet. You can also use VPN Gateway to send encrypted traffic between Azure virtual networks over the Microsoft network.

<img src="https://azure.microsoft.com/svghandler/azure-bastion/?width=600&height=315" width="80px" align="right">

**[Azure Bastion:](https://learn.microsoft.com/en-us/azure/bastion/bastion-overview)** Azure Bastion is a fully managed PaaS service that you provision to securely connect to virtual machines via private IP address. It provides secure and seamless RDP/SSH connectivity to your virtual machines directly over TLS from the Azure portal, or via the native SSH or RDP client already installed on your local computer. When you connect via Azure Bastion, your virtual machines don't need a public IP address, agent, or special client software.

<img src="https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQhggq3ThuvGbOvBmSVBjZIvNoq-oK-P7rRlQ&s" width="50px" align="right">

**[Application Gateway:](https://learn.microsoft.com/en-us/azure/application-gateway/overview)** Azure Application Gateway is a web traffic (OSI layer 7) load balancer that enables you to manage traffic to your web applications. It can make routing decisions based on additional attributes of an HTTP request, for example URI path or host headers. For example, you can route traffic based on the incoming URL. So if /images is in the incoming URL, you can route traffic to a specific set of servers (known as a pool) configured for images. If /video is in the URL, that traffic is routed to another pool that's optimized for videos.

<img src="https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRnLhoOuv9e7NLuruhd4L9hiGRkVF0KGxlIJA&s" width="50px" align="right">

**[App Service:](https://learn.microsoft.com/en-us/azure/app-service/overview)** Azure App Service is an HTTP-based service for hosting web applications, REST APIs, and mobile back ends. You can develop in your favorite language, be it .NET, .NET Core, Java, Node.js, PHP, and Python. Applications run and scale with ease on both Windows and Linux-based environments.

<img src="https://www.techielass.com/content/images/2021/03/azuredns-1.png" width="50px" align="right">

**[Azure Private DNS zone:](https://learn.microsoft.com/en-us/azure/dns/private-dns-privatednszone)** Azure Private DNS provides a reliable, secure DNS service to manage and resolve domain names in a virtual network without the need to add a custom DNS solution. By using private DNS zones, you can use your own custom domain names rather than the Azure-provided names available today.

<img src="https://user-images.githubusercontent.com/37974296/113137352-59e74380-921c-11eb-97e4-bcaf90528ae7.png" width="60px" align="right">

**[Private Endpoint:](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview)** A private endpoint is a network interface that uses a private IP address from your virtual network. This network interface connects you privately and securely to a service that's powered by Azure Private Link. By enabling a private endpoint, you're bringing the service into your virtual network.

The service could be an Azure service such as:

- Azure Storage
- Azure Cosmos DB
- Azure SQL Database
- Your own service, using Private Link service.

<img src="https://azure.microsoft.com/svghandler/monitor/?width=600&height=315" width="100px" align="right">

**[Azure Monitor:](https://learn.microsoft.com/en-us/azure/azure-monitor/overview)** Azure Monitor can collect, analyze, and act on telemetry data from cross-premises environments, including Azure and on-premises. Azure Monitor helps you maximize the performance and availability of your applications and proactively identify problems in seconds.

<h4 style= "color : skyblue">Azure Networking:</h4>
<img src="Images/IP.png" align="right">


[Azure reserves the first four addresses and the last address, for a total of five IP addresses within each subnet.](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-faq#are-there-any-restrictions-on-using-ip-addresses-within-these-subnets)

For example, the IP address range of 10.10.1.0/24 has the following reserved addresses:

- 10.10.1.0: Network address.
- 10.10.1.1: Reserved by Azure for the default gateway.
- 10.10.1.2, 10.10.1.3: Reserved by Azure to map the Azure DNS IP - addresses to the virtual network space.
- 10.10.1.255: Network broadcast address.

### Virtual Network Subnets:
#### GatewaySubnet:
The virtual network gateway requires a specific subnet named <mark>GatewaySubnet</mark>. The gateway subnet is part of the IP address range for your virtual network and contains the IP addresses that the virtual network gateway resources and services use. It's best to specify /27 or larger (/26, /25, etc.) for your gateway subnet.
#### AzureFirewallSubnet:
The AzureFirewallSubnet is a specialized subnet in Azure Virtual Network for hosting the Azure Firewall, a cloud-based network security service.Requires at least a /26 subnet (64 IP addresses).<mark>This subnet doesn't support network security groups (NSGs)</mark>.
#### Dedicated Subnets:
A [dedicated subnet](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-for-azure-services#services-that-can-be-deployed-into-a-virtual-network) in Azure is a specific range of IP addresses allocated within a Virtual Network (VNet) for particular resources or services. These subnets provide isolation and specific network configurations, such as for Azure Virtual Machines, VPN Gateways, Application Gateways, and other Azure services. They are crucial for managing security and network policies effectively.

<details>
<summary>The dedicated subnets are ,</summary>
<h6>Azure Virtual Machines</h6>
<h6>Azure Application Gateway</h6>
<h6>Azure Kubernetes Service</h6>
<h6>Azure VPN Gateway</h6>
<h6>Azure Firewall</h6>
<h6>Azure Bastion</h6>
<h6>Azure SQL Database Managed Instance</h6>
<h6>Azure Container Instances</h6>
</details>

#### Spoke network connectivity:
Virtual network peering or connected groups are non-transitive relationships between virtual networks. If you need spoke virtual networks to connect to each other, add a peering connection between those spokes or place them in the same network group.

#### Spoke connections through Azure Firewall or NVA:
The number of virtual network peerings per virtual network is limited. If you have many spokes that need to connect with each other, you could run out of peering connections. Connected groups also have limitations.

In this scenario, consider using user-defined routes (UDRs) to force spoke traffic to be sent to Azure Firewall or another NVA that acts as a router at the hub. This change allows the spokes to connect to each other. To support this configuration, you must implement Azure Firewall with forced tunnel configuration enabled. For more information, see Azure Firewall forced tunneling.

The topology in this architectural design facilitates egress flows. While Azure Firewall is primarily for egress security, it can also be an ingress point. For more considerations about hub NVA ingress routing, see Firewall and Application Gateway for virtual networks.

#### Spoke connections to remote networks through a hub gateway:
To configure spokes to communicate with remote networks through a hub gateway, you can use virtual network peerings or connected network groups.

To use virtual network peerings, in the virtual network Peering setup:

- Configure the peering connection in the <mark>hub to Allow gateway transit.</mark>
- Configure the peering connection in <mark>each spoke to Use the remote virtual network's gateway.</mark>
- Configure <mark>all peering connections to Allow forwarded traffic.</mark>

For more information, see [Create a virtual network peering](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-manage-peering?tabs=peering-portal#create-a-peering).

To use connected network groups:

- In Virtual Network Manager, create a network group and add member virtual networks.
- Create a hub and spoke connectivity configuration.
- For the Spoke network groups, select Hub as gateway.

#### Spoke network communications:
There are two main ways to allow spoke virtual networks to communicate with each other:

- 1.Communication via an NVA like a firewall and router. This method incurs a hop between the three spokes.
- 2.Communication by using virtual network peering or Virtual Network Manager direct connectivity between spokes. This approach doesn't cause a hop between the two spokes and is recommended for minimizing latency.


#### Communication through an NVA:
If you need connectivity between spokes, consider deploying Azure Firewall or another NVA in the hub. Then create routes to forward traffic from a spoke to the firewall or NVA, which can then route to the second spoke. In this scenario, you must <mark>configure the peering connections to allow forwarded traffic</mark>.

<img src="https://learn.microsoft.com/en-us/azure/architecture/networking/architecture/_images/spoke-spoke-routing.png">

You can also use a VPN gateway to route traffic between spokes, although this choice affects latency and throughput. For configuration details, see [Configure VPN gateway transit for virtual network peering](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-peering-gateway-transit).

Evaluate the services you share in the hub to ensure that the hub scales for a larger number of spokes. For instance, if your hub provides firewall services, consider your firewall solution's bandwidth limits when you add multiple spokes. You can move some of these shared services to a second level of hubs.



### Feedback
**Was this document helpful?** </br>
[![Documentation](https://img.shields.io/badge/Yes-blue?style=for-the-badge)](#) [![Documentation](https://img.shields.io/badge/No-blue?style=for-the-badge)](#)


<div align="right"><h4>Written By,</h4>
<a href="https://www.linkedin.com/in/seenu2002/">V.Srinivasan</a>
<h6>Cloud Engineer Intern @ CloudSlize</h6>
</div>

<div align="center">


[![Your Button Text](https://img.shields.io/badge/Thank_you!-Your_Color?style=for-the-badge)](#)

</div>

---

