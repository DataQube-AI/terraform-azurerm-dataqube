# The ingress inputs the module refuses, at plan time with Azure mocked. What
# each controller creates needs a real plan: the release pipeline's Qualify
# installs both (examples/quickstart and examples/application-gateway).

mock_provider "azurerm" {
  # Azure checks these are UUIDs even at plan time.
  mock_data "azurerm_client_config" {
    defaults = {
      object_id       = "00000000-0000-0000-0000-000000000001"
      tenant_id       = "00000000-0000-0000-0000-000000000002"
      subscription_id = "00000000-0000-0000-0000-000000000003"
    }
  }
}

variables {
  name     = "test"
  location = "swedencentral"
  dns      = { zone_name = "example.com" }
}

run "unknown_controller" {
  command = plan
  variables {
    ingress = { controller = "nginx" }
  }
  expect_failures = [var.ingress]
}

run "application_gateway_needs_network" {
  command = plan
  variables {
    ingress = { controller = "application_gateway" }
  }
  expect_failures = [var.ingress]
}

run "application_gateway_is_public" {
  command = plan
  variables {
    network = {}
    ingress = { controller = "application_gateway", internal = true, private_ip = "10.60.0.10" }
  }
  expect_failures = [var.ingress]
}

run "application_gateway_subnet_is_24_or_smaller" {
  command = plan
  variables {
    network = {}
    ingress = { controller = "application_gateway", application_gateway = { subnet = "10.60.18.0/23" } }
  }
  expect_failures = [var.ingress]
}

run "application_gateway_subnet_is_a_cidr" {
  command = plan
  variables {
    network = {}
    ingress = { controller = "application_gateway", application_gateway = { subnet = "10.60.18.0" } }
  }
  expect_failures = [var.ingress]
}
