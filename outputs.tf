# Author: Alejandro Galue <agalue@opennms.org>

output "cassandra_ipaddresses" {
  value = module.cassandra.*.ip_addresses
}

output "cassandra_interfaces" {
  value = module.cassandra.*.interfaces
}