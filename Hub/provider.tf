terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }
  required_version = ">= 1.1.0"

  backend "azurerm" {
    resource_group_name  = "Project_TF_RemoteState_RG"
    storage_account_name = "projectremotestatestacc"
    container_name       = "project-state-files"
    key                  = "Hub.tfstate"
  }
}
provider "azurerm" {
  features {}
}