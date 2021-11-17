# Author: Alejandro Galue <agalue@opennms.org>

output "ip_addresses" {
  value = [
    for intf in azurerm_network_interface.cassandra :
    intf.private_ip_address
  ]
}

output "interfaces" {
  value = [
    for intf in azurerm_network_interface.cassandra :
    intf.name
  ]
}

output "fqdn" {
  value = azurerm_public_ip.cassandra.fqdn
}