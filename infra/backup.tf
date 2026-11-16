resource "azurerm_recovery_services_vault" "main" {
  name                = "rsv-${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  storage_mode_type   = "LocallyRedundant"
  tags                = local.tags
}

resource "azurerm_backup_policy_vm" "daily" {
  name                = "bkpol-vm-daily-${local.suffix}"
  resource_group_name = azurerm_resource_group.main.name
  recovery_vault_name = azurerm_recovery_services_vault.main.name
  timezone            = "E. South America Standard Time"

  backup {
    frequency = "Daily"
    time      = "02:00"
  }

  retention_daily {
    count = 14
  }

  retention_weekly {
    count    = 4
    weekdays = ["Sunday"]
  }
}

resource "azurerm_backup_protected_vm" "web" {
  resource_group_name = azurerm_resource_group.main.name
  recovery_vault_name = azurerm_recovery_services_vault.main.name
  source_vm_id        = azurerm_linux_virtual_machine.web.id
  backup_policy_id    = azurerm_backup_policy_vm.daily.id
}