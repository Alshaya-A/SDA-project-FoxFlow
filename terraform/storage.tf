# ينشئ قرص البيانات ويربطه بالجهاز، ويجهز مساحة تخزين للنسخ الاحتياطية.
# Creates and attaches the data disk, and prepares storage for backups.

# Create a managed data disk for FF
resource "azurerm_managed_disk" "ff_data_disk" {
  name                 = "ff-data-disk"
  location             = azurerm_resource_group.foxflow_rg.location
  resource_group_name  = azurerm_resource_group.foxflow_rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 64
}

# Attach the data disk to the Ubuntu VM
resource "azurerm_virtual_machine_data_disk_attachment" "ff_data_disk_attachment" {
  managed_disk_id    = azurerm_managed_disk.ff_data_disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.ff_vm.id
  lun                = 0
  caching            = "ReadWrite"
}

# Create a Storage Account for FF backups
resource "azurerm_storage_account" "ff_backup_storage" {
  name                     = "ffbackupstorage01"
  resource_group_name      = azurerm_resource_group.foxflow_rg.name
  location                 = azurerm_resource_group.foxflow_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create a private container for GitLab backups
resource "azurerm_storage_container" "ff_backup_container" {
  name                  = "gitlab-backups"
  storage_account_id    = azurerm_storage_account.ff_backup_storage.id
  container_access_type = "private"
}
