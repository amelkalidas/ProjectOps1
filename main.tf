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
