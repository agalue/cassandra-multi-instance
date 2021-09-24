
locals {
  resource_group = var.resource_group_create ? azurerm_resource_group.main[0].name : var.resource_group
  seed_node = cidrhost(azurerm_subnet.main[0].address_prefixes[0], 10) # First instance on first VM
  onms_vm_name = "${var.user}-onmscas1"
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
  vm_size        = var.vm_size.cassandra
  os_image       = var.os_image
  num_vms        = var.num_vms
  num_instances  = var.num_instances
  seed_host      = local.seed_node
  settings       = var.cassandra_settings
}

resource "azurerm_public_ip" "opennms" {
  name                = "${local.onms_vm_name}-public-ip"
  location            = var.location
  resource_group_name = var.resource_group
  tags                = local.required_tags
  domain_name_label   = local.onms_vm_name
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

resource "azurerm_network_interface" "opennms" {
  count               = length(azurerm_subnet.main)
  name                = "${local.onms_vm_name}-nic${count.index}"
  location            = var.location
  resource_group_name = var.resource_group
  tags                = local.required_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main[count.index].id
    public_ip_address_id          = count.index == 0 ? azurerm_public_ip.opennms.id : null
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "opennms" {
  count                     = length(azurerm_subnet.main)
  network_interface_id      = azurerm_network_interface.opennms[count.index].id
  network_security_group_id = azurerm_network_security_group.opennms.id
}

data "template_file" "opennms" {
  template = file("opennms.yaml.tpl")

  vars = {
    user                 = var.user
    location             = var.location
    cassandra_seed       = local.seed_node
    cassandra_addresses  = join(",", flatten([for instance in module.cassandra: instance.ip_addresses]))
    cassandra_vms        = var.num_vms
    cassandra_instances  = var.num_instances
    newts_keyspace       = var.cassandra_settings.newts_keyspace
    newts_ttl            = var.opennms_settings.newts_ttl
    newts_resource_shard = var.opennms_settings.newts_resource_shard
    ring_buffer_size     = var.opennms_settings.ring_buffer_size
    cache_max_entries    = var.opennms_settings.cache_max_entries
  }
}

data "template_cloudinit_config" "opennms" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = data.template_file.opennms.rendered
  }
}

resource "azurerm_linux_virtual_machine" "opennms" {
  name                  = local.onms_vm_name
  resource_group_name   = var.resource_group
  location              = var.location
  size                  = var.vm_size.opennms
  admin_username        = var.user
  custom_data           = data.template_cloudinit_config.opennms.rendered
  network_interface_ids = azurerm_network_interface.opennms[*].id
  tags                  = local.required_tags

  admin_ssh_key {
    username   = var.user
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = var.os_image.publisher
    offer     = var.os_image.offer
    sku       = var.os_image.sku
    version   = var.os_image.version
  }

  os_disk {
    name                 = "${local.onms_vm_name}-os-disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}
