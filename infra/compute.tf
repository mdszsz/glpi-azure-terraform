resource "azurerm_network_interface" "vm" {
  #checkov:skip=CKV_AZURE_119:VM unica exposta por IP publico com NSG restrito. Application Gateway no roadmap
  name                = "nic-${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.10.1.4"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

resource "azurerm_linux_virtual_machine" "web" {
  #checkov:skip=CKV_AZURE_50:Extensao do Azure Monitor Agent e necessaria para observabilidade
  name                            = "vm-${local.suffix}"
  location                        = azurerm_resource_group.main.location
  resource_group_name             = azurerm_resource_group.main.name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.vm.id]
  tags                            = local.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    name                 = "osdisk-${local.suffix}"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/../scripts/cloud-init.yaml", {
    glpi_version = var.glpi_version
    domain       = local.fqdn
  }))

  identity {
    type = "SystemAssigned" # exigido pelo Azure Monitor Agent
  }

  boot_diagnostics {}

  lifecycle {
    ignore_changes = [custom_data] # mudar o cloud-init não recria a VM
  }
}