# Application Gateway for Containers on pogi's generic engine. It is stored and read back; no traffic flows. Run
# as the conformance block azurerm-a2-alb. It has its own folder because the azurerm provider waits five minutes
# before it sends the delete: CI runs this block in a job of its own, beside the others.
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "pogi-tf-a2-alb"
  location = "eastus"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "a2alb-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.31.0.0/16"]
}

resource "azurerm_subnet" "alb" {
  name                 = "a2alb-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.31.3.0/24"]
  delegation {
    name = "alb"
    service_delegation {
      name    = "Microsoft.ServiceNetworking/trafficControllers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Application Gateway for Containers
resource "azurerm_application_load_balancer" "alb" {
  name                = "a2alb-alb"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

resource "azurerm_application_load_balancer_frontend" "fe" {
  name                         = "a2alb-frontend"
  application_load_balancer_id = azurerm_application_load_balancer.alb.id
}

resource "azurerm_application_load_balancer_subnet_association" "assoc" {
  name                         = "a2alb-assoc"
  application_load_balancer_id = azurerm_application_load_balancer.alb.id
  subnet_id                    = azurerm_subnet.alb.id
}
