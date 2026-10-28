# Thin application services of pogi's generic Azure engine: Static Web Apps, Web PubSub,
# Relay, IoT Hub, Azure Maps, Automation and Recovery Services. They are stored and read back; nothing runs
# behind them (Notification Hubs are in terraform-azure-thin-a2-hubs; no site is served, no message flows, no runbook runs, no backup is taken).
resource "azurerm_static_web_app" "athin" {
  name                = "azstaticwebapps-pogi"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "westus2"
  sku_tier            = "Free"
  sku_size            = "Free"
  tags                = { env = "dev" }
}

resource "azurerm_web_pubsub" "athin" {
  name                = "azwebpubsub-pogi"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Free_F1"
  capacity            = 1
}

resource "azurerm_web_pubsub_hub" "athin" {
  name          = "chat"
  web_pubsub_id = azurerm_web_pubsub.athin.id
  depends_on    = [azurerm_web_pubsub.athin]
}

resource "azurerm_relay_namespace" "athin" {
  name                = "azrelay-pogi"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku_name            = "Standard"
}

resource "azurerm_relay_hybrid_connection" "athin" {
  name                          = "azrelay-hc"
  resource_group_name           = azurerm_resource_group.rg.name
  relay_namespace_name          = azurerm_relay_namespace.athin.name
  requires_client_authorization = false
}

resource "azurerm_iothub" "athin" {
  name                = "aziothub-pogi"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku {
    name     = "S1"
    capacity = 1
  }
}

resource "azurerm_iothub_consumer_group" "athin" {
  name                   = "reports"
  iothub_name            = azurerm_iothub.athin.name
  eventhub_endpoint_name = "events"
  resource_group_name    = azurerm_resource_group.rg.name
}

resource "azurerm_maps_account" "athin" {
  name                = "azmaps-pogi"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "global"
  sku_name            = "G2"
}

resource "azurerm_automation_account" "athin" {
  name                = "azautomation-pogi"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Basic"
}

resource "azurerm_automation_runbook" "athin" {
  name                    = "hello"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.athin.name
  log_verbose             = true
  log_progress            = true
  runbook_type            = "PowerShell"

  publish_content_link {
    uri = "https://example.test/hello.ps1"
  }
}

resource "azurerm_recovery_services_vault" "athin" {
  name                = "azrecoveryservices-pogi"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
}

resource "azurerm_backup_policy_vm" "athin" {
  name                = "daily"
  resource_group_name = azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.athin.name

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 10
  }
}
