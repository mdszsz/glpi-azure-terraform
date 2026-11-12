# Leitura da zona existente (data = só consulta, não gerencia)
data "azurerm_dns_zone" "main" {
  name                = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group
}

# glpi.mszsz.com.br -> IP público da VM (registro alias)
resource "azurerm_dns_a_record" "glpi" {
  name                = var.dns_record_name
  zone_name           = data.azurerm_dns_zone.main.name
  resource_group_name = var.dns_zone_resource_group
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.vm.id
  tags                = local.tags
}

# Só a Let's Encrypt pode emitir certificado para este nome
resource "azurerm_dns_caa_record" "glpi" {
  name                = var.dns_record_name
  zone_name           = data.azurerm_dns_zone.main.name
  resource_group_name = var.dns_zone_resource_group
  ttl                 = 300

  record {
    flags = 0
    tag   = "issue"
    value = "letsencrypt.org"
  }
}