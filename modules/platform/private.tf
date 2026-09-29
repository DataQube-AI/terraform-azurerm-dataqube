# Private endpoints for the registry, Key Vault and Azure OpenAI (with
# var.network.private_endpoints), each with its privatelink DNS zone linked to
# the installation's network so the cluster resolves them privately.

locals {
  private_endpoints = var.network != null && var.network.private_endpoints
  private_cluster   = var.network != null && var.network.private_cluster
  management_ranges = var.network == null ? [] : var.network.management_ip_ranges
  internal_ingress  = var.ingress.internal

  private_link = local.private_endpoints ? {
    registry  = { zone = "privatelink.azurecr.io", resource = azurerm_container_registry.this.id, subresource = "registry" }
    key_vault = { zone = "privatelink.vaultcore.azure.net", resource = azurerm_key_vault.this.id, subresource = "vault" }
    openai    = { zone = "privatelink.openai.azure.com", resource = azurerm_cognitive_account.openai.id, subresource = "account" }
  } : {}
}

resource "azurerm_subnet" "endpoints" {
  count                = local.private_endpoints ? 1 : 0
  name                 = "snet-endpoints"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this[0].name
  address_prefixes     = [var.network.endpoints_subnet]
}

resource "azurerm_private_dns_zone" "private_link" {
  for_each            = local.private_link
  name                = each.value.zone
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "private_link" {
  for_each            = local.private_link
  name                = "vnet-${local.base}"
  private_dns_zone_id = azurerm_private_dns_zone.private_link[each.key].id
  virtual_network_id  = azurerm_virtual_network.this[0].id
  tags                = local.tags
}

resource "azurerm_private_endpoint" "this" {
  for_each            = local.private_link
  name                = "pe-${local.base}-${each.key}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.endpoints[0].id

  private_service_connection {
    name                           = "${local.base}-${each.key}"
    private_connection_resource_id = each.value.resource
    subresource_names              = [each.value.subresource]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = each.key
    private_dns_zone_ids = [azurerm_private_dns_zone.private_link[each.key].id]
  }

  tags = local.tags
}
