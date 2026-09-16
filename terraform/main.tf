# ينشئ مجموعة موارد Azure والشبكة الفرعية للسيرفر.
# Creates the Azure resource group and the server subnet.

resource "azurerm_resource_group" "foxflow_rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_subnet" "foxflow_subnet" {
  name                 = "foxflow-subnet"
  resource_group_name  = azurerm_resource_group.foxflow_rg.name
  virtual_network_name = azurerm_virtual_network.foxflow_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}
