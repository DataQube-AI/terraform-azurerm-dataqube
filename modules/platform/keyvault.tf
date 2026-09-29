# Every credential the installation generates is written here (write-only:
# never into Terraform state) and read back into the cluster by modules/app.
resource "azurerm_key_vault" "this" {
  name                       = "kv-${var.name}-${local.suffix}"
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  # With private endpoints only the management ranges get in from outside
  # (Terraform writes the credentials here); nothing in the cluster reads it.
  public_network_access_enabled = !local.private_endpoints || length(local.management_ranges) > 0
  dynamic "network_acls" {
    for_each = local.private_endpoints ? [1] : []
    content {
      default_action = "Deny"
      bypass         = "AzureServices"
      ip_rules       = local.management_ranges
    }
  }

  tags = local.tags
}

resource "azurerm_role_assignment" "key_vault_officer" {
  for_each             = local.operators
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = each.value
}

# Azure RBAC grants take a while to reach the Key Vault data plane; writing a
# secret the moment the grant exists fails with 403.
resource "time_sleep" "key_vault_rbac" {
  depends_on      = [azurerm_role_assignment.key_vault_officer]
  create_duration = "90s"
}
