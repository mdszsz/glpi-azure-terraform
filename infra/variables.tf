variable "location" {
  type    = string
  default = "eastus"
}

variable "location_short" {
  type    = string
  default = "eus"
}

variable "environment" {
  type    = string
  default = "prd"
}

variable "workload" {
  type    = string
  default = "web"
}

variable "instance" {
  type    = string
  default = "001"
}

variable "dns_zone_name" {
  type        = string
  default     = "mszsz.com.br"
  description = "Zona DNS que já existe no Azure"
}

variable "dns_zone_resource_group" {
  type    = string
  default = "rg-recursos-permanentes"
}

variable "dns_record_name" {
  type    = string
  default = "glpi"
}

variable "glpi_version" {
  type    = string
  default = "10.0.28"
}

variable "vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "admin_username" {
  type    = string
  default = "azureadmin"
}

variable "admin_ssh_public_key" {
  type        = string
  description = "Conteúdo de ~/.ssh/glpi_azure.pub"
}

variable "admin_source_ip" {
  type        = string
  description = "Seu IP público em CIDR, ex.: 203.0.113.10/32"

  validation {
    condition     = can(cidrhost(var.admin_source_ip, 0))
    error_message = "Informe um CIDR válido, ex.: 203.0.113.10/32."
  }
}

variable "alert_email" {
  type = string
}

variable "mysql_server_name" {
  type        = string
  default     = "db-prd-web-eus-001"
  description = "Precisa ser único em todo o Azure"
}

variable "mysql_sku_name" {
  type    = string
  default = "B_Standard_B1ms"
}

variable "mysql_version" {
  type    = string
  default = "8.0.21"
}