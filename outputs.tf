# يحدد المعلومات التي يعرضها Terraform، مثل عنوان الجهاز وأسماء الموارد.
# Defines the information Terraform displays, such as the server IP address and resource names.

output "vm_public_ip" {
  description = "Public IP address of the FF VM"
  value       = azurerm_public_ip.foxflow_public_ip.ip_address
}

output "vm_name" {
  description = "Name of the FF Ubuntu VM"
  value       = azurerm_linux_virtual_machine.ff_vm.name
}

output "resource_group_name" {
  description = "Azure Resource Group used by FF"
  value       = azurerm_resource_group.foxflow_rg.name
}

output "backup_storage_account_name" {
  description = "Storage Account used for FF backups"
  value       = azurerm_storage_account.ff_backup_storage.name
}

output "backup_container_name" {
  description = "Blob container used for GitLab backups"
  value       = azurerm_storage_container.ff_backup_container.name
}