# Resource Group configuration

resource "azurerm_resource_group" "CI_PJOPS_VM_RG" {
  name     = "CI_PJOPS_VM_RG"
  location = var.Location
}

resource "azurerm_resource_group" "ImportedRG" {
  name     = "RG01"
  location = var.Location
  tags = {
    Owner = "Amel"
    ORG = "DevOps"
  }
}

# Security Group

resource "azurerm_network_security_group" "PJOPS_SG01" {
  name                = "PJOPS_DEFAULT_SG"
  location            = var.Location
  resource_group_name = azurerm_resource_group.CI_PJOPS_VM_RG.name
}

resource "azurerm_network_security_group" "PJOPS_SG02" {
  name = "PJOPS_SG02"
  location = var.Location
  resource_group_name = azurerm_resource_group.CI_PJOPS_VM_RG.name
  
}

# Vnet Configuration

resource "azurerm_virtual_network" "PJOPS_Vnet" {
  name                = "PJOPS_PROD_VNET"
  location            = var.Location
  resource_group_name = azurerm_resource_group.CI_PJOPS_VM_RG.name
  address_space       = ["10.0.0.0/16"]
  tags = {
    environment = "DevOps"
  }
}

resource "azurerm_subnet" "PJOPS_SUBNET_PUB" {
  name                 = "Public_Subnet01"
  resource_group_name  = azurerm_resource_group.CI_PJOPS_VM_RG.name
  virtual_network_name = azurerm_virtual_network.PJOPS_Vnet.name
  address_prefixes     = ["10.0.1.0/24"]

}

resource "azurerm_subnet" "PJOPS_SUBNET_PRVT" {
  name                 = "Private_Subnet01"
  resource_group_name  = azurerm_resource_group.CI_PJOPS_VM_RG.name
  virtual_network_name = azurerm_virtual_network.PJOPS_Vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# VM Configuration 

resource "azurerm_network_interface" "PublicVM_NIC" {

  name                = "HOST01-nic"
  location            = var.Location
  resource_group_name = azurerm_resource_group.CI_PJOPS_VM_RG.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.PJOPS_SUBNET_PUB.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [ azurerm_subnet.PJOPS_SUBNET_PUB ]
}
  


resource "azurerm_linux_virtual_machine" "example" {
  name                = "Host-0"
  resource_group_name = azurerm_resource_group.CI_PJOPS_VM_RG.name
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