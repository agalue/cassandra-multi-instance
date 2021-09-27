vm_size = {
  cassandra = "Standard_D48s_v4" # 48 Cores and 192 GB of RAM
  opennms   = "Standard_D8s_v4"  #  8 Cores and  32 GB of RAM
}

os_image = {
  publisher = "OpenLogic"
  offer     = "CentOS"
  sku       = "7_9"
  version   = "latest"
}

cassandra_settings = {
  version                = "3.11.6"
  disk_size              = 200
  cluster_name           = "Test Production Newts"
  dc_name                = "datacenter1"
  endpoint_snitch        = "SimpleSnitch"
  dynamic_snitch         = true
  num_tokens             = 256
  replication_factor     = 2
  newts_keyspace         = "test_newts"
  compaction_window_size = 7
  compaction_window_unit = "DAYS"
  expired_sstable_check  = 86400
  gc_grace_seconds       = 604800
}
