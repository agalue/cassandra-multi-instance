
variable "user" {
  description = "The user to access VMs and name prefix for Azure resources."
  type        = string
  default     = "agalue"
}

variable "name_prefix" {
  description = "A prefix to add to all Azure resources, to make them unique."
  type        = string
  default     = "agalue"
}

variable "resource_group_create" {
  description = "Set to true to create the resource group."
  type        = bool
  default     = false
}

variable "resource_group" {
  description = "The name of the Azure Resource Group."
  type        = string
  default     = "support-testing"
}

variable "location" {
  description = "The name of the Azure Location."
  type        = string
  default     = "eastus"
}

variable "address_space" {
  description = "The Virtual Network Address Space."
  type        = string
  default     = "14.0.0.0/16"
}

# Each subnet CIDR must exist within the address_space of the chosen virtual network.
# Due to how routing in Azure works, each NIC of each Cassandra VM would live on a different subnet.
variable "subnets" {
  description = "The subnet ranges for each Cassandra instance; the size determines the number of NICs per VM"
  type        = list(string)
  default     = [
    "14.0.1.0/24",
    "14.0.2.0/24",
    "14.0.3.0/24",
    "14.0.4.0/24"
  ]
}

variable "vm_size" {
  description = "The size of the VMs in Azure per kind."
  type = object({
    cassandra = string
    opennms   = string
  })
  default = {
    cassandra = "Standard_D16s_v4" # 16 Cores and 64 GB of RAM
    opennms   = "Standard_D8s_v4"  #  8 Cores and 32 GB of RAM
  }
}

# Must be consistent with the chosen Location/Region
# Please avoid RedHat/RHEL due to some cloud-init issues with 7.9
# Keep in mind that cloud-init in 7.9 is a lot slower than 8.4
variable "os_image" {
  description = "The OS Image to use for OpenNMS and Cassandra."
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "8_4" # Either 8_4 or 7_9 depending on your needs
    version   = "latest"
  }
}

variable "num_vms" {
  description = "The number of Cassandra Servers; that doesn't define the size of the cluster."
  type        = number
  default     = 3
}

variable "num_instances" {
  description = "The number of Cassandra Instances per Server; must be less or equal to the available subnets, and less than 9."
  type        = number
  default     = 3

  validation {
    condition = (
      var.num_instances <= 9
    )
    error_message = "The num_instances cannot be greater than 9."
  }
}

variable "cassandra_settings" {
  description = "The Cassandra settings."
  type = object({
    version                = string
    disk_size              = number
    cluster_name           = string
    dc_name                = string
    endpoint_snitch        = string
    dynamic_snitch         = bool
    num_tokens             = number
    replication_factor     = number
    newts_keyspace         = string
    compaction_window_size = number
    compaction_window_unit = string
    expired_sstable_check  = number
    gc_grace_seconds       = number
  })
  default ={
    version                = "latest" # Either 'latest' or '4.0.1', '3.11.10', and so on.
    disk_size              = 100 # Disk size in GB per Instance
    cluster_name           = "OpenNMS"
    dc_name                = "Main"
    endpoint_snitch        = "GossipingPropertyFileSnitch" # Either GossipingPropertyFileSnitch or SimpleSnitch
    dynamic_snitch         = false
    num_tokens             = 16
    replication_factor     = 2
    newts_keyspace         = "newts"
    # TWCS settings for the newts.samples table
    compaction_window_size = 7
    compaction_window_unit = "DAYS"
    expired_sstable_check  = 86400 # Expressed in seconds
    gc_grace_seconds       = 604800 # Expressed in seconds
  }
}

variable "opennms_settings" {
  description = "The OpenNMS settings"
  type = object({
    newts_ttl            = number
    newts_resource_shard = number
    ring_buffer_size     = number
    cache_max_entries    = number
  })
  default ={
    newts_ttl            = 31540000
    newts_resource_shard = 604800
    ring_buffer_size     = 2097152
    cache_max_entries    = 1000000
  }
}
