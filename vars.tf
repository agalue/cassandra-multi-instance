
variable "user" {
  description = "User to access VMs and prefix for Azure resources"
  type        = string
  default     = "agalue"
}

variable "resource_group_create" {
  description = "Set to true to create the resource group"
  type        = bool
  default     = false
}

variable "resource_group" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "support-testing"
}

variable "location" {
  description = "Name of the Azure Location"
  type        = string
  default     = "eastus"
}

variable "address_space" {
  description = "Virtual Network Address Space"
  type        = string
  default     = "14.0.0.0/16"
}

# Must exist within the address_space of the chosen virtual network
# Each Cassandra instance on each VM should live on a different subnet (because of Azure)
variable "subnets" {
  description = "Subnet Ranges for each Cassandra instance"
  type        = list(string)
  default     = [
    "14.0.1.0/24",
    "14.0.2.0/24",
    "14.0.3.0/24",
    "14.0.4.0/24"
  ]
}

variable "vm_size" {
  description = "Size of the VM"
  type        = string
  default     = "Standard_D16s_v4" # 16 Cores and 64 GB of RAM
}

# Must be consistent with the chosen Location/Region
variable "os_image" {
  description = "OS Image to use for OpenNMS and Cassandra"
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
  description = "Number of Cassandra Servers"
  type        = number
  default     = 3
}

variable "num_instances" {
  description = "Number of Cassandra Instances per Server (>= available subnets)"
  type        = number
  default     = 3
}

variable "cassandra_settings" {
  description = "Cassandra settings"
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
    # For the newts.samples table
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
    compaction_window_size = 7
    compaction_window_unit = "DAYS"
    expired_sstable_check  = 86400 # Check frequency in Minutes
    gc_grace_seconds       = 604800
  }
}
