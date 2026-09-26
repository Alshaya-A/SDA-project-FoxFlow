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

  # Public HTTP entry point. Caddy redirects application traffic to HTTPS and
  # uses this port for ACME certificate validation.
  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Public HTTPS entry point for both GitLab and the FoxFlow application.
  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
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

  # Ports 3000, 5050, 8080, and 8443 deliberately remain private. Caddy is the
  # only public HTTP entry point; the Runner uses the registry over the VNet.
}

resource "azurerm_subnet_network_security_group_association" "foxflow_subnet_nsg" {
  subnet_id                 = azurerm_subnet.foxflow_subnet.id
  network_security_group_id = azurerm_network_security_group.foxflow_nsg.id
}
