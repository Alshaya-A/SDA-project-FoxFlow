# يحدد إصدارات Terraform ومزود Azure المطلوبة للمشروع.
# Specifies the Terraform and Azure provider versions required by the project.

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
