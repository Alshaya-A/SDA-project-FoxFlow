# يضبط مزود Azure ويحدد الاشتراك المستخدم لإدارة الموارد.
# Configures the Azure provider and selects the subscription used to manage resources.

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
