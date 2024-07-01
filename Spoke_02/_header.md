## Spoke_02 Network :
- 1.First we have to create the Resource Group for Spoke_02.
- 2.We should create the Virtual Network for Spoke_02 with address space.
- 3.The Spoke_02 Virtual Network has multiple subnets with address prefixes.
- 4.Atleast one spoke must host a high-availability virtual machine Scale Set(VMSS) service.
- 5.The VMSS should support layer 7 capabilities and SSL certificate termination (Use Application Gateway).
- 6.Each Network Security Group should associate with their respective Subnets.
- 7.We have to establish the peering between Hub and Spoke_02.

## Architecture Diagram :