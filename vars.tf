# Author: Alejandro Galue <agalue@opennms.org>

variable "user" {
  description = "The username to access VMs, and the value for the Owner tag."
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

# The chosen IP addressing scheme prevents having more than 24 Servers in the cluster.
# This limitation doesn't represent a problem for the Lab Environment.
variable "num_vms" {
  description = "The number of Cassandra Servers; it doesn't define the size of the cluster, and must be less than 24."
  type        = number
  default     = 3

  validation {
    condition = (
      var.num_vms <= 24
    )
    error_message = "The num_vms cannot be greater than 24."
  }
}

# The chosen IP addressing scheme prevents having more than 8 Instances per Server in the cluster.
# This limitation doesn't represent a problem for the Lab Environment.
variable "num_instances" {
  description = "The number of Cassandra Instances per Server; must be less or equal to the available subnets, and less than 8."
  type        = number
  default     = 3

  validation {
    condition = (
      var.num_instances <= 8
    )
    error_message = "The num_instances cannot be greater than 8."
  }
}

variable "address_space" {
  description = "The Virtual Network Address Space."
  type        = string
  default     = "14.0.0.0/16"
}

# Each subnet CIDR must exist within the address_space of the chosen virtual network.
# Due to how routing in Azure works, each NIC of each Cassandra VM would live on a different subnet.
# The chosen IP addressing scheme prevents having more than 8 subnets in the cluster.
variable "subnets" {
  description = "The subnet ranges for each Cassandra instance; the size determines the number of NICs per VM (cannot have more than 8 elements)"
  type        = list(string)
  default = [
    "14.0.1.0/24",
    "14.0.2.0/24",
    "14.0.3.0/24",
    "14.0.4.0/24"
  ]
  validation {
    condition = (
      length(var.subnets) <= 8
    )
    error_message = "The subnets array cannot have more than 8 elements."
  }
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
# Please avoid RedHat/RHEL as it requires a subscription to install packages on it.
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

variable "cassandra_settings" {
  description = "The Cassandra settings."
  type = object({
    version                = string
    disk_size              = number
    cluster_name           = string
    use_ipaddr             = bool
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
  default = {
    version            = "latest" # Either 'latest' or '4.0.1', '3.11.10', and so on (avoid 3.11.11).
    disk_size          = 100      # Disk size in GB per Cassandra Instance
    cluster_name       = "OpenNMS"
    use_ipaddr         = false    # false to use Interface Names for the Cassandra Listeners
    dc_name            = "Main"                        # Valid when using GossipingPropertyFileSnitch
    endpoint_snitch    = "GossipingPropertyFileSnitch" # Either GossipingPropertyFileSnitch or SimpleSnitch
    dynamic_snitch     = false
    num_tokens         = 16
    replication_factor = 2
    newts_keyspace     = "newts"
    # TWCS settings for the newts.samples table
    compaction_window_size = 7
    compaction_window_unit = "DAYS"
    expired_sstable_check  = 86400  # Expressed in seconds
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
  default = {
    newts_ttl            = 31540000
    newts_resource_shard = 604800
    ring_buffer_size     = 2097152
    cache_max_entries    = 1000000
  }
}
