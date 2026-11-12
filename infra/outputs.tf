output "public_ip" {
  value = azurerm_public_ip.vm.ip_address
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/glpi_azure ${var.admin_username}@${azurerm_public_ip.vm.ip_address}"
}

output "mysql_fqdn" {
  value = azurerm_mysql_flexible_server.main.fqdn
}

output "glpi_url" {
  value = "https://${local.fqdn}"
}

output "mysql_admin_password" {
  value     = random_password.mysql_admin.result
  sensitive = true
}