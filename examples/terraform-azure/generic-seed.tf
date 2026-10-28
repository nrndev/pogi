# Services of pogi's generic Azure engine: DNS and Logic Apps (Policy is in terraform-azure-thin-a2-policy). Nothing
# runs behind a zone or a workflow: a zone answers no queries and a workflow never fires.
resource "azurerm_dns_zone" "generic" {
  name                = "generic.example.test"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = { env = "dev" }
}

resource "azurerm_dns_a_record" "generic_www" {
  name                = "www"
  zone_name           = azurerm_dns_zone.generic.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = ["10.0.0.4", "10.0.0.5"]
}

resource "azurerm_dns_cname_record" "generic_app" {
  name                = "app"
  zone_name           = azurerm_dns_zone.generic.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  record              = "www.generic.example.test"
}

resource "azurerm_logic_app_workflow" "generic" {
  name                = "pogi-tf-workflow"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = { env = "dev" }
}
