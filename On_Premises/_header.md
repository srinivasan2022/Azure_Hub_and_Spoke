## On_Premises Network :
- 1.First we have to create the Resource Group for On_Premises.
- 2.We should create the Virtual Network for Hub with address space.
- 3.The Hub Virtual Network has multiple subnets with address prefixes.
- 4.We have to create the subnet for VPN Gateway.
- 5.We should create the Local Network Gateway and Connection service for establish the connection between On_premises and Hub.

## Architecture Diagram :
![On_Premises](https://github.com/user-attachments/assets/0baf48b4-dbc2-437d-9ded-f530f33f23d9)

###### Apply the Terraform configurations :
Deploy the resources using Terraform,
```
terraform init
```
```
terraform plan
```
```
terraform apply
```
