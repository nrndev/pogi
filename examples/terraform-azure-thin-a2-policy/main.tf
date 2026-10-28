# Azure Policy, moved out of terraform-azure so it runs in a job of its own: the provider waits about 100
# seconds each for the definition and the assignment, and again on destroy. Run as the conformance block
# azurerm-a2-policy. The policy is evaluated: it only audits, so it denies nothing.
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "pogi-tf-a2-policy"
  location = "eastus"
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
