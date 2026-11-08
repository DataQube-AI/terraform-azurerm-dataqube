# The cluster's VM sizes: those cluster sets, else its architecture's defaults; checked there.
module "vm_sizes" {
  source         = "./vm_sizes"
  architecture   = var.cluster.architecture
  system_vm_size = var.cluster.system_vm_size
  agent_pool     = var.cluster.agent_pool != null
  agent_vm_size  = try(var.cluster.agent_pool.vm_size, null)
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = "aks-${local.base}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = local.base
  kubernetes_version  = var.cluster.kubernetes_version
  sku_tier            = var.cluster.sku_tier

  # Entra ID + Azure RBAC only: no local admin kubeconfig exists to leak.
  local_account_disabled = true
  azure_active_directory_role_based_access_control {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    azure_rbac_enabled = true
  }

  # Ordinary node pools, sized by these inputs (not node auto-provisioning).
  node_provisioning_profile {
    mode = "Manual"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    load_balancer_sku   = "standard"
  }

  # A private cluster has no public API; otherwise the API answers only the
  # authorized ranges (and the management ranges) when any are given.
  private_cluster_enabled = local.private_cluster
  dynamic "api_server_access_profile" {
    for_each = !local.private_cluster && length(concat(var.cluster.api_server_authorized_ip_ranges, local.management_ranges)) > 0 ? [1] : []
    content {
      authorized_ip_ranges = distinct(concat(var.cluster.api_server_authorized_ip_ranges, local.management_ranges))
    }
  }

  default_node_pool {
    name                         = "system"
    vm_size                      = module.vm_sizes.system
    node_count                   = var.cluster.system_node_count
    zones                        = var.cluster.availability_zones
    os_disk_size_gb              = 64
    vnet_subnet_id               = local.nodes_subnet_id
    only_critical_addons_enabled = false
    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  # Application Gateway mode: AGIC, the AKS add-on, programs the gateway
  # (application_gateway.tf) from the release's Ingress objects.
  dynamic "ingress_application_gateway" {
    for_each = local.application_gateway ? [1] : []
    content {
      gateway_id = azurerm_application_gateway.this[0].id
    }
  }

  tags = local.tags
}

# Per-session agent pods, isolated from the services: they carry the label
# and tolerate the taint (modules/app sets agentCore.nodeSelector/tolerations).
resource "azurerm_kubernetes_cluster_node_pool" "agents" {
  count                 = var.cluster.agent_pool == null ? 0 : 1
  name                  = "agents"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = module.vm_sizes.agents
  auto_scaling_enabled  = true
  min_count             = var.cluster.agent_pool.min_count
  max_count             = var.cluster.agent_pool.max_count
  zones                 = var.cluster.availability_zones
  os_disk_size_gb       = 128
  vnet_subnet_id        = local.nodes_subnet_id
  node_labels           = { "dataqube.dev/pool" = "agents" }
  node_taints           = ["dataqube.dev/pool=agents:NoSchedule"]
  # Azure's own default, declared so plans stay empty after creation.
  upgrade_settings {
    max_surge = "10%"
  }
  tags = local.tags
}

# The operators (and the identity running Terraform, which installs the
# release) administer the cluster through Azure RBAC.
resource "azurerm_role_assignment" "cluster_admin" {
  for_each             = local.operators
  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = each.value
}

# Azure RBAC grants take a while to reach the cluster's API, as they do Key
# Vault's: installing the release the moment the grant exists is refused
# (403). The cluster output's host and certificate come through this, so the
# Kubernetes and Helm providers reach the cluster only after it. 90 seconds
# isn't always enough (Azure says up to 10 minutes), so the examples then wait
# until the cluster accepts their own sign-in (wait-for-cluster-access.sh).
resource "time_sleep" "cluster_rbac" {
  depends_on      = [azurerm_role_assignment.cluster_admin]
  create_duration = "90s"
  triggers = {
    host                   = azurerm_kubernetes_cluster.this.kube_config[0].host
    cluster_ca_certificate = azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate
  }
}
