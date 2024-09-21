# Resource Group configuration

resource "azurerm_resource_group" "prod_rg" {
  name     = "OPS_PROD_RG"
  location = var.Location
}

resource "azurerm_resource_group" "Test_RG01" {
  name     = "RG01"
  location = var.Location
  tags = {
    Owner = "Amel"
    ORG = "DevOps"
  }
}

# Security Group

resource "azurerm_network_security_group" "public_sg" {
  name                = "OPS_Public_SG"
  location            = var.Location
  resource_group_name = azurerm_resource_group.prod_rg.name
}

resource "azurerm_network_security_group" "private_sg" {
  name = "ops_private_sg"
  location = var.Location
  resource_group_name = azurerm_resource_group.prod_rg.name
  
}

# Vnet Configuration

resource "azurerm_virtual_network" "Prod_vnet" {
  name                = "OPS_PROD_VNET"
  location            = var.Location
  resource_group_name = azurerm_resource_group.prod_rg.name
  address_space       = ["10.0.0.0/16"]
  tags = {
    environment = "DevOps"
  }
}

resource "azurerm_subnet" "public_subnet01" {
  name                 = "Ops_Public_subnet01"
  resource_group_name  = azurerm_resource_group.prod_rg.name
  virtual_network_name = azurerm_virtual_network.Prod_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  service_endpoints = [ "Microsoft.Storage" ]                               # this enables service endpoint for the storage accoutn to connect securely.

}

resource "azurerm_subnet" "private_subnet01" {
  name                 = "ops_private_subnet01"
  resource_group_name  = azurerm_resource_group.prod_rg.name
  virtual_network_name = azurerm_virtual_network.Prod_vnet.name
  default_outbound_access_enabled = false                                   # this makes the subnet Private.
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints = [ "Microsoft.Storage" ]                               # this enables service endpoint for the storage accoutn to connect securely.

}

# NIC Configuration 

resource "azurerm_network_interface" "PublicVM_NIC" {

  name                = "HOST01-nic"
  location            = var.Location
  resource_group_name = azurerm_resource_group.prod_rg.name

  ip_configuration {
    name                          = "public_bound"
    subnet_id                     = azurerm_subnet.public_subnet01.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [ azurerm_subnet.public_subnet01 ]
}
  
resource "azurerm_network_interface" "prvt_db_nic" {
  name = "db_nic"
  location = var.Location
  resource_group_name = azurerm_resource_group.prod_rg.name

  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.private_subnet01.id
    private_ip_address_allocation = "Dynamic"

  }
  
  depends_on = [ azurerm_subnet.private_subnet01 ]
}

# VM Configuration

resource "azurerm_linux_virtual_machine" "prod_public_Vm" {
  name                = "Host-0"
  resource_group_name = azurerm_resource_group.prod_rg.name
  location            = var.Location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  disable_password_authentication = false       
  admin_password = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.PublicVM_NIC.id,
  ]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "prod_Private_Vm" {
  name                = "prod-db-01"
  resource_group_name = azurerm_resource_group.prod_rg.name
  location            = var.Location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  disable_password_authentication = false
  admin_password = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.prvt_db_nic.id,
  ]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# Storage Account

resource "azurerm_storage_account" "prod_storage" {
  name = var.storageaccount
  resource_group_name = azurerm_resource_group.prod_rg.name
  location = var.Location
  account_tier = "Standard"
  account_replication_type = "LRS"
  tags = {
    environment = "DevOps"

  }  
}
resource "azurerm_storage_account_network_rules" "prod_storage_networkrule" {
  storage_account_id = azurerm_storage_account.prod_storage.id

  default_action             = "Allow"
  virtual_network_subnet_ids = [azurerm_subnet.private_subnet01.id , azurerm_subnet.public_subnet01.id]
  bypass                     = ["Metrics","AzureServices"]
}

resource "azurerm_storage_share" "prod_share" {
  name                 = "prodshare"
  storage_account_name = azurerm_storage_account.prod_storage.name
  quota                = 50 
}
# Backup Configuration for the VM

resource "azurerm_recovery_services_vault" "recovery_vault" {
  name = var.recoveryvaultname
  location = var.Location
  resource_group_name = azurerm_resource_group.prod_rg.name
  sku = "Standard"
  immutability = "Disabled"
  storage_mode_type = "LocallyRedundant"
  soft_delete_enabled = false
}

resource "azurerm_backup_policy_vm" "vm_backup_policy" {
  name = "Infrastrucure-server-backup-policy"
  resource_group_name = azurerm_resource_group.prod_rg.name
  recovery_vault_name = azurerm_recovery_services_vault.recovery_vault.name
  
  timezone = "UTC"

  backup {
    frequency = "Daily"
    time = "22:00"
  }
  
  retention_daily {
    count = "7"
  }

}

resource "azurerm_backup_protected_vm" "host0-backup" {
  recovery_vault_name = azurerm_recovery_services_vault.recovery_vault.name
  resource_group_name = azurerm_resource_group.prod_rg.name
  source_vm_id = azurerm_linux_virtual_machine.prod_public_Vm.id
  backup_policy_id = azurerm_backup_policy_vm.vm_backup_policy.id  
  depends_on = [ azurerm_recovery_services_vault.recovery_vault ]
}
resource "azurerm_backup_protected_vm" "database-backup" {
  recovery_vault_name = azurerm_recovery_services_vault.recovery_vault.name
  resource_group_name = azurerm_resource_group.prod_rg.name
  source_vm_id = azurerm_linux_virtual_machine.prod_Private_Vm.id
  backup_policy_id = azurerm_backup_policy_vm.vm_backup_policy.id  
  depends_on = [ azurerm_recovery_services_vault.recovery_vault ]
}