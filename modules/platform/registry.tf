# The release's images are imported here (modules/app), so the running
# installation never depends on the vendor's registry being reachable.
resource "azurerm_container_registry" "this" {
  name                = "acr${replace(local.base, "-", "")}${local.suffix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  # Premium is the only tier with private endpoints.
  sku                           = local.private_endpoints ? "Premium" : "Standard"
  admin_enabled                 = false
  public_network_access_enabled = !local.private_endpoints
  tags                          = local.tags
}

# The kubelet identity pulls every pod's image, including the per-session
# agent pods the orchestrator creates, so no image pull secret is needed.
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                            = azurerm_container_registry.this.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}
