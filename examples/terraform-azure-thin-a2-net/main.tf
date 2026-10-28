# Azure networking products on pogi's generic engine: Network Watcher, DDoS Protection, Virtual Network
# Manager, Route Server, ExpressRoute, VPN Gateway, and Web Application Firewall policies. They are stored and
# read back; no traffic flows. Run as the conformance block azurerm-a2-net. Application Gateway for Containers
# is in terraform-azure-thin-a2-alb: the provider waits five minutes before it deletes one, so it has its own job.
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "pogi-tf-a2-net"
  location = "eastus"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "a2net-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.30.0.0/16"]
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.30.1.0/24"]
}

resource "azurerm_subnet" "route_server" {
  name                 = "RouteServerSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.30.2.0/24"]
}

resource "azurerm_public_ip" "vpn" {
  name                = "a2net-pip-vpn"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "rs" {
  name                = "a2net-pip-rs"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Watcher
resource "azurerm_network_watcher" "nw" {
  name                = "a2net-watcher"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# DDoS Protection
resource "azurerm_network_ddos_protection_plan" "ddos" {
  name                = "a2net-ddos"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# Virtual Network Manager
resource "azurerm_network_manager" "nm" {
  name                = "a2net-manager"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  scope_accesses      = ["Connectivity"]
  scope {
    subscription_ids = ["/subscriptions/${data.azurerm_client_config.current.subscription_id}"]
  }
}

resource "azurerm_network_manager_network_group" "ng" {
  name               = "a2net-group"
  network_manager_id = azurerm_network_manager.nm.id
}

# Route Server
resource "azurerm_route_server" "rs" {
  name                             = "a2net-routeserver"
  resource_group_name              = azurerm_resource_group.rg.name
  location                         = azurerm_resource_group.rg.location
  sku                              = "Standard"
  public_ip_address_id             = azurerm_public_ip.rs.id
  subnet_id                        = azurerm_subnet.route_server.id
  branch_to_branch_traffic_enabled = true
}

resource "azurerm_route_server_bgp_connection" "peer" {
  name            = "a2net-peer"
  route_server_id = azurerm_route_server.rs.id
  peer_asn        = 65501
  peer_ip         = "10.30.9.4"
}

# ExpressRoute
resource "azurerm_express_route_circuit" "er" {
  name                  = "a2net-circuit"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  service_provider_name = "Equinix"
  peering_location      = "Silicon Valley"
  bandwidth_in_mbps     = 50
  sku {
    tier   = "Standard"
    family = "MeteredData"
  }
}

resource "azurerm_express_route_circuit_authorization" "er" {
  name                       = "a2net-auth"
  express_route_circuit_name = azurerm_express_route_circuit.er.name
  resource_group_name        = azurerm_resource_group.rg.name
}

# VPN Gateway
resource "azurerm_virtual_network_gateway" "vpn" {
  name                = "a2net-vpngw"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  ip_configuration {
    name                          = "default"
    public_ip_address_id          = azurerm_public_ip.vpn.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }
}

resource "azurerm_local_network_gateway" "site" {
  name                = "a2net-site"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  gateway_address     = "203.0.113.10"
  address_space       = ["192.168.0.0/24"]
}

resource "azurerm_virtual_network_gateway_connection" "site" {
  name                       = "a2net-conn"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn.id
  local_network_gateway_id   = azurerm_local_network_gateway.site.id
  shared_key                 = "pogi-test-shared-key"
}

# Web Application Firewall policy
resource "azurerm_web_application_firewall_policy" "waf" {
  name                = "a2net-waf"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  policy_settings {
    enabled = true
    mode    = "Prevention"
  }
  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}
