# Azure services whose provider waits a long time on delete, moved out of terraform-azure so they run in a job of
# their own: Notification Hubs (the provider waits about 150 seconds for the namespace and again for the hub) and
# Policy (about 100 seconds each for the definition and the assignment). Run as the conformance block
# azurerm-a2-hubs. Nothing runs behind them: no notification is sent. The policy is evaluated: it only audits,
# so it denies nothing.
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

resource "azurerm_policy_definition" "generic_audit" {
  name         = "pogi-tf-audit-location"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Audit resources outside East US"

  policy_rule = jsonencode({
    if   = { field = "location", notEquals = "eastus" }
    then = { effect = "audit" }
  })
}

resource "azurerm_resource_group_policy_assignment" "generic_audit" {
  name                 = "pogi-tf-audit"
  resource_group_id    = azurerm_resource_group.rg.id
  policy_definition_id = azurerm_policy_definition.generic_audit.id
}
