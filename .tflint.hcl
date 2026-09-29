plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "azurerm" {
  enabled = true
  version = "0.30.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

# Lifecycle blocks cannot be conditional, and the quickstart is disposable by
# design. Protection of production data is the production path's job (and the
# README's warning), not a literal prevent_destroy that would block teardown.
rule "azurerm_resources_missing_prevent_destroy" {
  enabled = false
}
