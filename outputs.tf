output "cassandra" {
  value = flatten([
    for instance in module.cassandra:
    instance.ip_addresses
  ])
}