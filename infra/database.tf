resource "random_password" "mysql_admin" {
  length           = 24
  special          = true
  override_special = "-_.%"
  min_special      = 2
}

resource "azurerm_mysql_flexible_server" "main" {
  name                         = var.mysql_server_name
  location                     = azurerm_resource_group.main.location
  resource_group_name          = azurerm_resource_group.main.name
  administrator_login          = "glpiadmin"
  administrator_password       = random_password.mysql_admin.result
  sku_name                     = var.mysql_sku_name
  version                      = var.mysql_version
  delegated_subnet_id          = azurerm_subnet.db.id
  private_dns_zone_id          = azurerm_private_dns_zone.mysql.id
  backup_retention_days        = 14
  geo_redundant_backup_enabled = false
  tags                         = local.tags

  storage {
    size_gb           = 20
    auto_grow_enabled = true
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql]

  lifecycle {
    ignore_changes = [zone]
  }
}

resource "azurerm_mysql_flexible_database" "glpi" {
  name                = "glpi"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_flexible_server.main.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

resource "azurerm_mysql_flexible_server_configuration" "params" {
  for_each = {
    require_secure_transport = "ON"
    slow_query_log           = "ON"
    long_query_time          = "2"
    audit_log_enabled        = "ON"
    audit_log_events         = "CONNECTION,DDL"
  }

  name                = each.key
  value               = each.value
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_flexible_server.main.name
}