resource "azurerm_dns_zone" "this" {
  count               = var.dns.create_zone ? 1 : 0
  name                = var.dns.zone_name
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

data "azurerm_dns_zone" "existing" {
  count               = var.dns.create_zone ? 0 : 1
  name                = var.dns.zone_name
  resource_group_name = var.dns.existing_zone_resource_group_name
}

locals {
  ingress_ip = local.application_gateway ? azurerm_public_ip.application_gateway[0].ip_address : (
    local.internal_ingress ? var.ingress.private_ip : azurerm_public_ip.ingress[0].ip_address
  )
  zone_id             = var.dns.create_zone ? azurerm_dns_zone.this[0].id : data.azurerm_dns_zone.existing[0].id
  zone_resource_group = var.dns.create_zone ? azurerm_resource_group.this.name : var.dns.existing_zone_resource_group_name
  app_fqdn            = "${var.dns.app_subdomain}.${var.dns.zone_name}"
  auth_fqdn           = "${var.dns.auth_subdomain}.${var.dns.zone_name}"
}

# The Envoy Gateway's public address: in the cluster's node resource group,
# where AKS's own identity may attach it to the gateway's load balancer.
resource "azurerm_public_ip" "ingress" {
  count               = local.internal_ingress || local.application_gateway ? 0 : 1
  name                = "pip-${local.base}-ingress"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_kubernetes_cluster.this.node_resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.cluster.availability_zones
  tags                = local.tags
}

resource "azurerm_dns_a_record" "app" {
  name                = var.dns.app_subdomain
  zone_name           = var.dns.zone_name
  resource_group_name = local.zone_resource_group
  ttl                 = 300
  records             = [local.ingress_ip]
  depends_on          = [azurerm_dns_zone.this]
}

resource "azurerm_dns_a_record" "auth" {
  name                = var.dns.auth_subdomain
  zone_name           = var.dns.zone_name
  resource_group_name = local.zone_resource_group
  ttl                 = 300
  records             = [local.ingress_ip]
  depends_on          = [azurerm_dns_zone.this]
}

# cert-manager proves domain control with DNS-01 records in this zone, as
# this identity through AKS workload identity. It may edit this zone only.
resource "azurerm_user_assigned_identity" "cert_manager" {
  name                = "id-${local.base}-cert-manager"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_role_assignment" "cert_manager_dns" {
  scope                = local.zone_id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.cert_manager.principal_id
}

resource "azurerm_federated_identity_credential" "cert_manager" {
  name                      = "cert-manager-dns01"
  user_assigned_identity_id = azurerm_user_assigned_identity.cert_manager.id
  issuer                    = azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject                   = "system:serviceaccount:cert-manager:cert-manager"
  audience                  = ["api://AzureADTokenExchange"]
}
