resource "azurerm_virtual_network" "this" {
  count               = var.network == null ? 0 : 1
  name                = "vnet-${local.base}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.network.address_space
  tags                = local.tags
}

resource "azurerm_subnet" "nodes" {
  count                = var.network == null ? 0 : 1
  name                 = "snet-nodes"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this[0].name
  address_prefixes     = [var.network.nodes_subnet]
}

# Only the database lives here: Azure delegates the whole subnet to it.
resource "azurerm_subnet" "database" {
  count                = var.network == null ? 0 : 1
  name                 = "snet-database"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this[0].name
  address_prefixes     = [var.network.database_subnet]
  # Azure adds this to a subnet delegated to flexible server (its backups go
  # to storage); declared so plans stay empty.
  service_endpoint {
    service = "Microsoft.Storage"
  }
  delegation {
    name = "postgresql"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# With a subnet it does not own, AKS needs rights on it to place load
# balancers and node interfaces.
resource "azurerm_role_assignment" "cluster_network" {
  count                            = var.network == null ? 0 : 1
  scope                            = azurerm_subnet.nodes[0].id
  role_definition_name             = "Network Contributor"
  principal_id                     = azurerm_kubernetes_cluster.this.identity[0].principal_id
  skip_service_principal_aad_check = true
}

locals {
  nodes_subnet_id = var.network == null ? null : azurerm_subnet.nodes[0].id
}
