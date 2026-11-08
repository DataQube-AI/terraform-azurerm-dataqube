# Application Gateway mode (ingress.controller = "application_gateway"): an
# Azure Application Gateway v2 fronts the cluster, as a platform team's
# gateway would, and the AKS add-on (AGIC) programs it from the release's
# Ingress objects. Terraform owns the gateway itself; AGIC owns its routing.

locals {
  application_gateway = var.ingress.controller == "application_gateway"
  # The gateway must be created with one route; these placeholders are
  # replaced by AGIC's own on its first sync.
  agw = {
    gateway_ip  = "gateway-ip"
    frontend_ip = "public"
    port        = "http"
    placeholder = "placeholder"
  }
}

# AGIC on an overlay network extends the pod network to this subnet, which
# the gateway must have to itself.
resource "azurerm_subnet" "application_gateway" {
  count                = local.application_gateway ? 1 : 0
  name                 = "snet-application-gateway"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this[0].name
  address_prefixes     = [var.ingress.application_gateway.subnet]
  delegation {
    name = "application-gateway"
    service_delegation {
      name    = "Microsoft.Network/applicationGateways"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_public_ip" "application_gateway" {
  count               = local.application_gateway ? 1 : 0
  name                = "pip-${local.base}-agw"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.cluster.availability_zones
  tags                = local.tags
}

resource "azurerm_application_gateway" "this" {
  count               = local.application_gateway ? 1 : 0
  name                = "agw-${local.base}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  zones               = var.cluster.availability_zones

  sku {
    name = "Standard_v2"
    tier = "Standard_v2"
  }
  autoscale_configuration {
    min_capacity = 1
    max_capacity = var.ingress.application_gateway.max_capacity
  }
  # TLS 1.2 and up; the gateway's default policy allows older versions.
  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  gateway_ip_configuration {
    name      = local.agw.gateway_ip
    subnet_id = azurerm_subnet.application_gateway[0].id
  }
  frontend_ip_configuration {
    name                 = local.agw.frontend_ip
    public_ip_address_id = azurerm_public_ip.application_gateway[0].id
  }

  frontend_port {
    name = local.agw.port
    port = 80
  }
  backend_address_pool {
    name = local.agw.placeholder
  }
  backend_http_settings {
    name                  = local.agw.placeholder
    port                  = 80
    protocol              = "Http"
    cookie_based_affinity = "Disabled"
  }
  http_listener {
    name                           = local.agw.placeholder
    frontend_ip_configuration_name = local.agw.frontend_ip
    frontend_port_name             = local.agw.port
    protocol                       = "Http"
  }
  request_routing_rule {
    name                       = local.agw.placeholder
    rule_type                  = "Basic"
    priority                   = 20000
    http_listener_name         = local.agw.placeholder
    backend_address_pool_name  = local.agw.placeholder
    backend_http_settings_name = local.agw.placeholder
  }

  # AGIC rewrites the routing from the Ingress objects (and tags the gateway
  # as its own); Terraform keeps the SKU, scaling, TLS policy and addresses.
  lifecycle {
    ignore_changes = [
      backend_address_pool,
      backend_http_settings,
      frontend_port,
      http_listener,
      probe,
      redirect_configuration,
      request_routing_rule,
      rewrite_rule_set,
      ssl_certificate,
      url_path_map,
      tags,
    ]
  }

  tags = local.tags
}

# The add-on's identity reads and rewrites the gateway, which joins it to its
# subnet and public IP: Network Contributor on those three, and no more.
resource "azurerm_role_assignment" "agic" {
  for_each = local.application_gateway ? {
    gateway   = azurerm_application_gateway.this[0].id
    subnet    = azurerm_subnet.application_gateway[0].id
    public_ip = azurerm_public_ip.application_gateway[0].id
  } : {}
  scope                            = each.value
  role_definition_name             = "Network Contributor"
  principal_id                     = azurerm_kubernetes_cluster.this.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
  skip_service_principal_aad_check = true
}
