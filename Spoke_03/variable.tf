variable "rg_name" {
  type = string
  description = "The name of the Resource Group"
  validation {
    condition = length(var.rg_name)>0
    error_message = "The name must be provided"
  }

}

variable "rg_location" {
  type = string
  description = "The Location of the Resource Group"
  validation {
    condition = length(var.rg_location)>0
    error_message = "The Location must be provided"
  }
}

variable "vnet_details" {
  type = map(object({
    vnet_name = string
    address_space = string
  }))
  description = "The details of the VNET"
}

variable "subnet_details" {
  type = map(object({
    subnet_name = string
    address_prefix = string
  }))
  description = "The details of the Subnets"
}

variable "app_service_plan_name" {
  type = string
  default = "The name of app service plan"
}

variable "web_app_name" {
  type = string
  default = "The name of web app name"
}

variable "private_endpoint_name" {
 type = string
 description = "The name of private endpoint name"
}

variable "private_dns_zone_name" {
 type = string
 description = "The name of private DNS zone name"
}

variable "private_dns_zone_vnet_link" {
 type = string
 description = "The name of private DNS virtual network link name"
}

variable "private_dns_a_record" {
 type = string
 description = "The name of private DNS virtual network link name"
}