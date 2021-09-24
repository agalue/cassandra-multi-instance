resource "azurerm_resource_group" "main" {
  count    = var.resource_group_create ? 1 : 0
  name     = var.resource_group
  location = var.location
  tags     = local.required_tags
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.user}-cassandra-vnet"
  location            = var.location
  resource_group_name = local.resource_group
  address_space       = [var.address_space]
  tags                = local.required_tags
}

resource "azurerm_subnet" "main" {
  count                = length(var.subnets)
  name                 = "subnet${count.index + 1}"
  resource_group_name  = local.resource_group
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnets[count.index]]
}

resource "azurerm_network_security_group" "main" {
  name                = "${var.user}-cassandra-sg"
  location            = var.location
  resource_group_name = var.resource_group
  tags                = local.required_tags

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "opennms" {
  name                = "${var.user}-opennms-sg"
  location            = var.location
  resource_group_name = var.resource_group
  tags                = local.required_tags

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "WebUI"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8980"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
