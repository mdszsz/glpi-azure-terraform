resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 1 # teto de custo
  tags                = local.tags
}

resource "azurerm_monitor_action_group" "ops" {
  name                = "ag-${local.suffix}"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "glpiops"
  tags                = local.tags

  email_receiver {
    name                    = "admin"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

# Agente e coleta de métricas/logs da VM
resource "azurerm_virtual_machine_extension" "ama" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.web.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
}

resource "azurerm_monitor_data_collection_rule" "vm" {
  name                = "dcr-${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags

  destinations {
    log_analytics {
      name                  = "law"
      workspace_resource_id = azurerm_log_analytics_workspace.main.id
    }
  }

  data_flow {
    streams      = ["Microsoft-Perf", "Microsoft-Syslog"]
    destinations = ["law"]
  }

  data_sources {
    performance_counter {
      name                          = "perf"
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "Processor(*)\\% Processor Time", # formato Linux: sem \\ no início
        "Memory(*)\\% Used Memory",
        "Logical Disk(*)\\% Used Space",
      ]
    }

    syslog {
      name           = "syslog"
      streams        = ["Microsoft-Syslog"]
      facility_names = ["auth", "authpriv", "daemon", "syslog"]
      log_levels     = ["Warning", "Error", "Critical", "Alert", "Emergency"]
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "vm" {
  name                    = "dcra-${local.suffix}"
  target_resource_id      = azurerm_linux_virtual_machine.web.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vm.id
  depends_on              = [azurerm_virtual_machine_extension.ama]
}

# Logs do MySQL
resource "azurerm_monitor_diagnostic_setting" "mysql" {
  name                       = "diag-${var.mysql_server_name}"
  target_resource_id         = azurerm_mysql_flexible_server.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "MySqlSlowLogs"
  }

  enabled_log {
    category = "MySqlAuditLogs"
  }
}

# Alertas
locals {
  alerts = {
    vm-cpu = {
      scope     = azurerm_linux_virtual_machine.web.id
      namespace = "Microsoft.Compute/virtualMachines"
      metric    = "Percentage CPU"
      operator  = "GreaterThan"
      threshold = 85
      desc      = "CPU da VM acima de 85% por 15 min"
    }
    vm-availability = {
      scope     = azurerm_linux_virtual_machine.web.id
      namespace = "Microsoft.Compute/virtualMachines"
      metric    = "VmAvailabilityMetric"
      operator  = "LessThan"
      threshold = 1
      desc      = "VM indisponível"
    }
    db-cpu = {
      scope     = azurerm_mysql_flexible_server.main.id
      namespace = "Microsoft.DBforMySQL/flexibleServers"
      metric    = "cpu_percent"
      operator  = "GreaterThan"
      threshold = 80
      desc      = "CPU do MySQL acima de 80% por 15 min"
    }
    db-storage = {
      scope     = azurerm_mysql_flexible_server.main.id
      namespace = "Microsoft.DBforMySQL/flexibleServers"
      metric    = "storage_percent"
      operator  = "GreaterThan"
      threshold = 80
      desc      = "Disco do MySQL acima de 80%"
    }
  }
}

resource "azurerm_monitor_metric_alert" "this" {
  for_each            = local.alerts
  name                = "alert-${each.key}-${local.suffix}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [each.value.scope]
  description         = each.value.desc
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = local.tags

  criteria {
    metric_namespace = each.value.namespace
    metric_name      = each.value.metric
    aggregation      = "Average"
    operator         = each.value.operator
    threshold        = each.value.threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}