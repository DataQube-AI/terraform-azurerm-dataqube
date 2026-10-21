# The cluster's VM sizes: those cluster sets, else its architecture's defaults. Pure module:
# no providers, so tests/ plans it with nothing else.
locals {
  defaults = {
    arm64 = { system = "Standard_D4ps_v6", agents = "Standard_D8ps_v6" }
    amd64 = { system = "Standard_D4as_v6", agents = "Standard_D8as_v6" }
  }
}

output "system" {
  description = "The system pool's VM size."
  value       = coalesce(var.system_vm_size, local.defaults[var.architecture].system)
}

output "agents" {
  description = "The agent pool's VM size; null without an agent pool."
  value       = var.agent_pool ? coalesce(var.agent_vm_size, local.defaults[var.architecture].agents) : null
}
