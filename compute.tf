# ينشئ جهاز Ubuntu الافتراضي وواجهة الشبكة وعنوان IP العام.
# Creates the Ubuntu virtual machine, network interface, and public IP address.

# Create a static Public IP for the FF VM
resource "azurerm_public_ip" "foxflow_public_ip" {
  name                = "foxflow-public-ip"
  location            = azurerm_resource_group.foxflow_rg.location
  resource_group_name = azurerm_resource_group.foxflow_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create the Network Interface and connect it to the subnet and Public IP
resource "azurerm_network_interface" "foxflow_nic" {
  name                = "foxflow-nic"
  location            = azurerm_resource_group.foxflow_rg.location
  resource_group_name = azurerm_resource_group.foxflow_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.foxflow_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.foxflow_public_ip.id
  }
}

# Create the Ubuntu VM
resource "azurerm_linux_virtual_machine" "ff_vm" {
  name                = "ff-vm"
  resource_group_name = azurerm_resource_group.foxflow_rg.name
  location            = azurerm_resource_group.foxflow_rg.location
  size                = "Standard_D2s_v7"
  admin_username      = "azureuser"

  network_interface_ids = [
    azurerm_network_interface.foxflow_nic.id
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("C:/Users/96653/.ssh/id_ed25519.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}