# The chat deployment's capacity, at plan time with Azure mocked: the default carries a workflow's
# subagents running side by side (100 ran out of tokens a minute and failed its steps), and an
# install that sets its own keeps it. The plans target the deployment: a mocked cluster has no
# kubelet identity for the rest of the module to read.

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

run "chat_defaults_to_300_thousand_tokens_a_minute" {
  command = plan
  plan_options {
    target = [azurerm_cognitive_deployment.chat]
  }
  assert {
    condition     = azurerm_cognitive_deployment.chat.sku[0].capacity == 300
    error_message = "the chat deployment's default capacity is 300"
  }
}

run "chat_keeps_an_installs_own_capacity" {
  command = plan
  plan_options {
    target = [azurerm_cognitive_deployment.chat]
  }
  variables {
    llm = { capacity = 100 }
  }
  assert {
    condition     = azurerm_cognitive_deployment.chat.sku[0].capacity == 100
    error_message = "llm.capacity sets the chat deployment's capacity"
  }
}
