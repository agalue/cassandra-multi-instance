
resource "azurerm_public_ip" "cassandra" {
  name                = "${var.hostname}-public-ip"
  location            = var.location
  resource_group_name = var.resource_group
  tags                = var.required_tags
  domain_name_label   = var.hostname
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

resource "azurerm_network_interface" "cassandra" {
  count               = length(var.subnet_cidrs)
  name                = "${var.hostname}-nic${count.index+1}"
  location            = var.location
  resource_group_name = var.resource_group
  tags                = var.required_tags

  ip_configuration {
    name                          = "main"
    subnet_id                     = var.subnet_ids[count.index]
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(var.subnet_cidrs[count.index], substr(var.hostname, -1, 0) * 10 + count.index + 1)
    public_ip_address_id          = count.index == 0 ? azurerm_public_ip.cassandra.id : null
  }
}

resource "azurerm_network_interface_security_group_association" "cassandra" {
  count                    = length(var.subnet_cidrs)
  network_interface_id      = azurerm_network_interface.cassandra[count.index].id
  network_security_group_id = var.nsg_id
}

data "template_file" "cassandra" {
  template = file("${path.module}/cassandra.yaml.tpl")

  vars = {
    number_of_instances    = var.num_instances
    cluster_size           = var.num_vms * var.num_instances
    seed_host              = var.seed_host
    version                = var.settings.version
    cluster_name           = var.settings.cluster_name
    dc_name                = var.settings.dc_name
    endpoint_snitch        = var.settings.endpoint_snitch
    dynamic_snitch         = var.settings.dynamic_snitch
    num_tokens             = var.settings.num_tokens
    replication_factor     = var.settings.replication_factor
    newts_keyspace         = var.settings.newts_keyspace
    compaction_window_size = var.settings.compaction_window_size
    compaction_window_unit = var.settings.compaction_window_unit
    expired_sstable_check  = var.settings.expired_sstable_check
    gc_grace_seconds       = var.settings.gc_grace_seconds
  }
}

data "template_cloudinit_config" "cassandra" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = data.template_file.cassandra.rendered
  }
}

resource "azurerm_linux_virtual_machine" "cassandra" {
  name                  = var.hostname
  resource_group_name   = var.resource_group
  location              = var.location
  size                  = var.vm_size
  admin_username        = var.user
  custom_data           = data.template_cloudinit_config.cassandra.rendered
  network_interface_ids = azurerm_network_interface.cassandra[*].id
  tags                  = var.required_tags

  allow_extension_operations = false

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
    name                 = "${var.hostname}-os-disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

resource "azurerm_managed_disk" "cassandra" {
  count                = length(var.subnet_cidrs)
  name                 = "${var.hostname}-disk${count.index+1}"
  resource_group_name  = var.resource_group
  tags                 = var.required_tags
  location             = var.location
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.settings.disk_size
}

resource "azurerm_virtual_machine_data_disk_attachment" "cassandra" {
  count              = length(var.subnet_cidrs)
  managed_disk_id    = azurerm_managed_disk.cassandra[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.cassandra.id
  lun                = "${count.index}"
  caching            = "ReadWrite"
}
