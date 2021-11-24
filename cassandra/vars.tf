# Author: Alejandro Galue <agalue@opennms.org>

variable "resource_group" {
  type = string
}

variable "location" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "subnet_cidrs" {
  type = list(string)
}

variable "nsg_id" {
  type = string
}

variable "required_tags" {
  type = map(string)
}

variable "hostname" {
  type = string
  validation {
    condition     = can(regex(".*\\d", var.hostname))
    error_message = "The hostname value must end with an numeric value."
  }
}

variable "user" {
  type = string
}

variable "vm_size" {
  type = string
}

variable "os_image" {
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
}

variable "num_vms" {
  type = number
}

variable "num_instances" {
  type = number
}

variable "seed_host" {
  type = string
}

variable "settings" {
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
}
