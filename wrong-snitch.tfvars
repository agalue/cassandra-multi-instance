# Author: Alejandro Galue <agalue@opennms.org>

# To guarantee 4 NICs and 4 Disks per Cassandra VM
subnets = [
  "14.0.1.0/24",
  "14.0.2.0/24",
  "14.0.3.0/24",
  "14.0.4.0/24",
]

user = "agalue"
name_prefix = "ag-env1"
num_vms = 3
num_instances=3

vm_size = {
  cassandra = "Standard_D48s_v4" # 48 Cores and 192 GB of RAM
  opennms   = "Standard_D32s_v4" # 32 Cores and 128 GB of RAM
}

os_image = {
  publisher = "OpenLogic"
  offer     = "CentOS"
  sku       = "7_9"
  version   = "latest"
}

cassandra_settings = {
  version                = "3.11.6"
  disk_size              = 500
  cluster_name           = "Test Production Newts"
  dc_name                = "datacenter1"
  endpoint_snitch        = "SimpleSnitch"
  dynamic_snitch         = true
  num_tokens             = 256
  replication_factor     = 2
  newts_keyspace         = "test_newts"
  compaction_window_size = 1
  compaction_window_unit = "HOURS"
  expired_sstable_check  = 5400
  gc_grace_seconds       = 604800
}

opennms_settings = {
  newts_ttl            = 31540000
  newts_resource_shard = 604800
  ring_buffer_size     = 4194304
  cache_max_entries    = 2000000
}
