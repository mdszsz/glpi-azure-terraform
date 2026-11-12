locals {
  suffix = "${var.environment}-${var.workload}-${var.location_short}-${var.instance}"
  fqdn   = "${var.dns_record_name}.${var.dns_zone_name}" # glpi.mszsz.com.br

  tags = {
    project     = "glpi"
    environment = var.environment
    managed_by  = "terraform"
    repository  = "glpi-azure-terraform"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.suffix}"
  location = var.location
  tags     = local.tags
}