
locals {
  resource_group = var.resource_group_create ? azurerm_resource_group.main[0].name : var.resource_group
  required_tags = {
    Owner = "${var.user}"
  }
}

module "cassandra" {
  source         = "./cassandra"
  count          = var.num_vms
  resource_group = local.resource_group
  location       = var.location
  subnet_ids     = azurerm_subnet.main[*].id
  subnet_cidrs   = azurerm_subnet.main[*].address_prefixes[0]
  nsg_id         = azurerm_network_security_group.main.id
  required_tags  = local.required_tags
  hostname       = "${var.user}-cassandra${count.index + 1}"
  user           = var.user
  vm_size        = var.vm_size
  os_image       = var.os_image
  num_vms        = var.num_vms
  num_instances  = var.num_instances
  seed_host      = cidrhost(azurerm_subnet.main[0].address_prefixes[0], 10) # First instance on first VM
  settings       = var.cassandra_settings
}
