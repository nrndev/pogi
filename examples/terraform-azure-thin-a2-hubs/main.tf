# Notification Hubs, moved out of terraform-azure so they run in a job of their own: the provider waits about 150
# seconds for the namespace and again for the hub. Run as the conformance block azurerm-a2-hubs. Nothing runs
# behind them: no notification is sent. (Policy is in terraform-azure-thin-a2-policy.)
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "pogi-tf-a2-hubs"
  location = "eastus"
}

resource "azurerm_notification_hub_namespace" "athin" {
  name                = "aznotificationhubs-pogi"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  namespace_type      = "NotificationHub"
  sku_name            = "Free"
}

resource "azurerm_notification_hub" "athin" {
  name                = "orders"
  namespace_name      = azurerm_notification_hub_namespace.athin.name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}
