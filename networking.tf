# ينشئ الشبكة الرئيسية ويضبط قواعد الأمان ويربطها بالشبكة الفرعية.
# Creates the virtual network and security rules, and associates them with the subnet.

resource "azurerm_virtual_network" "foxflow_vnet" {
  name                = "foxflow-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.foxflow_rg.location
  resource_group_name = azurerm_resource_group.foxflow_rg.name
}

resource "azurerm_network_security_group" "foxflow_nsg" {
  name                = "foxflow-nsg"
  location            = azurerm_resource_group.foxflow_rg.location
  resource_group_name = azurerm_resource_group.foxflow_rg.name

  # SSH access to the Ubuntu VM
  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # GitLab HTTP
  security_rule {
    name                       = "Allow-GitLab-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # GitLab HTTPS
  security_rule {
    name                       = "Allow-GitLab-HTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # GitLab SSH for repository access
  security_rule {
    name                       = "Allow-GitLab-SSH"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "2222"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "foxflow_subnet_nsg" {
  subnet_id                 = azurerm_subnet.foxflow_subnet.id
  network_security_group_id = azurerm_network_security_group.foxflow_nsg.id
}
