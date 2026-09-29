data "azurerm_client_config" "current" {}

# Globally unique names (ACR, Key Vault, OpenAI subdomain) need a suffix; it
# is stable for the life of the state.
resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

locals {
  suffix    = random_string.suffix.result
  base      = "dataqube-${var.name}"
  operators = toset(concat([data.azurerm_client_config.current.object_id], var.operator_object_ids))
  tags      = merge({ "managed-by" = "terraform-azurerm-dataqube", "dataqube-installation" = var.name }, var.tags)
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.base}"
  location = var.location
  tags     = local.tags
}
