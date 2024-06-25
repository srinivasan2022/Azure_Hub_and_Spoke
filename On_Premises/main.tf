resource "azurerm_resource_group" "On_Premises" {
   for_each = var.rg_details
   name     = each.value.rg_name
   location = each.value.rg_location
}

resource "azurerm_virtual_network" "On_Premises_vnet" {
    for_each = var.vnet_details
    name = each.value.vnet_name
    address_space = [each.value.address_space]
    resource_group_name = azurerm_resource_group.On_Premises["On_Premises_RG"].name
    location = azurerm_resource_group.On_Premises["On_Premises_RG"].location
    depends_on = [ azurerm_resource_group.On_Premises ]
}

resource "azurerm_subnet" "subnets" {
  for_each = var.subnet_details
  name = each.key
  address_prefixes = [each.value.address_prefix]
  virtual_network_name = azurerm_virtual_network.On_Premises_vnet["On_Premises_vnet"].name
  resource_group_name = azurerm_resource_group.On_Premises["On_Premises_RG"].name
  depends_on = [ azurerm_virtual_network.On_Premises_vnet ]
}

resource "azurerm_network_security_group" "nsg" {
  for_each = toset(local.subnet_names)
  name = each.key
  resource_group_name = azurerm_resource_group.On_Premises["On_Premises_RG"].name
  location = azurerm_resource_group.On_Premises["On_Premises_RG"].location

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

resource "azurerm_subnet_network_security_group_association" "nsg_ass" {
  for_each = { for idx , subnet in azurerm_subnet.subnets : idx => subnet.id}
  subnet_id                 = each.value
  network_security_group_id =   azurerm_network_security_group.nsg[local.nsg_names[each.key]].id
  depends_on = [ azurerm_network_security_group.nsg ]
}