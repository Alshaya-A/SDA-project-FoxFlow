# يعرّف إعدادات المشروع القابلة للتغيير وقيمها الافتراضية.
# Defines configurable project settings and their default values.

variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "foxflow-rg"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}