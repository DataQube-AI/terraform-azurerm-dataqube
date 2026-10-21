variable "architecture" {
  description = "The cluster's architecture: \"arm64\" or \"amd64\" (cluster.architecture)."
  type        = string
  validation {
    condition     = contains(["arm64", "amd64"], var.architecture)
    error_message = "cluster.architecture must be \"arm64\" or \"amd64\"."
  }
}

# Arm64 sizes carry "p" among the feature letters after the vCPU count
# (Standard_D4ps_v6, Standard_E8pds_v6, Standard_D4plds_v6); x86 sizes don't.
variable "system_vm_size" {
  description = "The system pool's size (cluster.system_vm_size); null for the architecture's default."
  type        = string
  default     = null
  validation {
    condition     = var.system_vm_size == null || can(regex("^Standard_[A-Za-z]+[0-9]+[a-z]*p[a-z]*_v[0-9]+$", var.system_vm_size)) == (var.architecture == "arm64")
    error_message = "cluster.system_vm_size must match cluster.architecture: an Arm64 size such as Standard_D4ps_v6 for arm64, an x86 size such as Standard_D4as_v6 for amd64."
  }
}

variable "agent_pool" {
  description = "Whether the cluster has an agent pool (cluster.agent_pool is set)."
  type        = bool
  default     = false
}

variable "agent_vm_size" {
  description = "The agent pool's size (cluster.agent_pool.vm_size); null for the architecture's default."
  type        = string
  default     = null
  validation {
    condition     = var.agent_vm_size == null || can(regex("^Standard_[A-Za-z]+[0-9]+[a-z]*p[a-z]*_v[0-9]+$", var.agent_vm_size)) == (var.architecture == "arm64")
    error_message = "cluster.agent_pool.vm_size must match cluster.architecture: an Arm64 size such as Standard_D8ps_v6 for arm64, an x86 size such as Standard_D8as_v6 for amd64."
  }
}
