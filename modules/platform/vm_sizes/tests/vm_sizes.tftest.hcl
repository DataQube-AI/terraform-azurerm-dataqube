# cluster.architecture: the default VM sizes it picks, and the sizes it refuses. Pure module: no
# providers.

run "arm64_defaults" {
  command = plan
  variables {
    architecture = "arm64"
    agent_pool   = true
  }
  assert {
    condition     = output.system == "Standard_D4ps_v6" && output.agents == "Standard_D8ps_v6"
    error_message = "arm64 should default to Standard_D4ps_v6 and Standard_D8ps_v6"
  }
}

run "amd64_defaults" {
  command = plan
  variables {
    architecture = "amd64"
    agent_pool   = true
  }
  assert {
    condition     = output.system == "Standard_D4as_v6" && output.agents == "Standard_D8as_v6"
    error_message = "amd64 should default to Standard_D4as_v6 and Standard_D8as_v6"
  }
}

run "no_agent_pool_no_agent_size" {
  command = plan
  variables {
    architecture = "amd64"
  }
  assert {
    condition     = output.agents == null
    error_message = "without an agent pool there is no agent size"
  }
}

run "a_size_of_its_architecture_is_kept" {
  command = plan
  variables {
    architecture   = "amd64"
    system_vm_size = "Standard_D8s_v6"
    agent_pool     = true
    agent_vm_size  = "Standard_E8as_v6"
  }
  assert {
    condition     = output.system == "Standard_D8s_v6" && output.agents == "Standard_E8as_v6"
    error_message = "sizes the architecture allows should be used as given"
  }
}

run "an_arm_size_on_amd64_is_refused" {
  command = plan
  variables {
    architecture   = "amd64"
    system_vm_size = "Standard_D4ps_v6"
  }
  expect_failures = [var.system_vm_size]
}

run "an_x86_agent_size_on_arm64_is_refused" {
  command = plan
  variables {
    architecture  = "arm64"
    agent_pool    = true
    agent_vm_size = "Standard_D8as_v6"
  }
  expect_failures = [var.agent_vm_size]
}

run "an_unknown_architecture_is_refused" {
  command = plan
  variables {
    architecture = "x86_64"
  }
  expect_failures = [var.architecture]
}
