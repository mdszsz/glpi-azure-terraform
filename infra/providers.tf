terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-tfstate-eus-001"
    storage_account_name = "sttfstateglpi10569"
    container_name       = "tfstate"
    key                  = "glpi/prd.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
  # subscription_id vem de ARM_SUBSCRIPTION_ID
}