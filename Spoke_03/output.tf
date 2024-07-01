output "Spoke_03_RG" {
  value = azurerm_resource_group.Spoke_03
}

output "app_plan" {
  value = azurerm_app_service_plan.plan
}

output "web_app" {
  value = azurerm_app_service.web_app
}