# Author: Alejandro Galue <agalue@opennms.org>

output "onms_server" {
  value = azurerm_public_ip.opennms.fqdn
}

output "cassandra_servers" {
  value = module.cassandra.*.fqdn
}

output "cassandra_ipaddresses" {
  value = module.cassandra.*.ip_addresses
}

output "cassandra_interfaces" {
  value = module.cassandra.*.interfaces
}
