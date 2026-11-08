output "resource_group_name" {
  description = "The installation's resource group."
  value       = azurerm_resource_group.this.name
}

output "cluster" {
  description = "How to reach the cluster's API (Entra ID authentication; no local accounts). host and cluster_ca_certificate are known only once the operators' grants have reached the cluster."
  value = {
    name                   = azurerm_kubernetes_cluster.this.name
    host                   = time_sleep.cluster_rbac.triggers.host
    cluster_ca_certificate = time_sleep.cluster_rbac.triggers.cluster_ca_certificate
  }
}

output "agent_pool_enabled" {
  description = "Whether session agent pods have their own pool (label and taint dataqube.dev/pool=agents)."
  value       = var.cluster.agent_pool != null
}

output "registry" {
  description = "The installation's container registry."
  value = {
    id           = azurerm_container_registry.this.id
    name         = azurerm_container_registry.this.name
    login_server = azurerm_container_registry.this.login_server
  }
}

output "key_vault" {
  description = "The Key Vault holding the installation's generated credentials. ready_after is a dependency handle: write secrets only after it."
  value = {
    id          = azurerm_key_vault.this.id
    name        = azurerm_key_vault.this.name
    ready_after = time_sleep.key_vault_rbac.id
  }
}

output "llm" {
  description = "The model endpoints the product uses: chat, embeddings, speech and image generation, all on one Azure OpenAI account. A switched-off feature's deployment is null."
  value = {
    endpoint   = azurerm_cognitive_account.openai.endpoint
    base_url   = "${trimsuffix(azurerm_cognitive_account.openai.endpoint, "/")}/openai/v1"
    deployment = azurerm_cognitive_deployment.chat.name
    model      = var.llm.model
    # null when the feature is switched off.
    embeddings_deployment = one(azurerm_cognitive_deployment.embeddings[*].name)
    speech_deployment     = one(azurerm_cognitive_deployment.speech[*].name)
    image_deployment      = one(azurerm_cognitive_deployment.image[*].name)
  }
}

output "llm_api_key" {
  description = "The Azure OpenAI account key. Sensitive: held in state because the account resource carries it."
  value       = azurerm_cognitive_account.openai.primary_access_key
  sensitive   = true
}

output "ingress" {
  description = "The public address and names the gateway serves."
  value = {
    controller          = var.ingress.controller
    internal            = local.internal_ingress
    ip_address          = local.ingress_ip
    ip_name             = one(azurerm_public_ip.ingress[*].name)
    ip_resource_group   = azurerm_kubernetes_cluster.this.node_resource_group
    app_fqdn            = local.app_fqdn
    auth_fqdn           = local.auth_fqdn
    zone_name           = var.dns.zone_name
    zone_resource_group = local.zone_resource_group
    subscription_id     = data.azurerm_client_config.current.subscription_id
  }
}

output "name_servers" {
  description = "Delegate dns.zone_name to these from its parent zone (only when the module created the zone)."
  value       = var.dns.create_zone ? azurerm_dns_zone.this[0].name_servers : []
}

output "cert_manager_identity_client_id" {
  description = "Client ID of the identity cert-manager uses for DNS-01."
  value       = azurerm_user_assigned_identity.cert_manager.client_id
}

output "database" {
  description = "The managed database (null when PostgreSQL runs in the cluster). The admin password is in Key Vault under password_secret_name."
  value = local.managed_database ? {
    host                 = azurerm_postgresql_flexible_server.this[0].fqdn
    name                 = azurerm_postgresql_flexible_server_database.dataqube[0].name
    user                 = local.database_admin
    password_secret_name = azurerm_key_vault_secret.database_admin[0].name
    password_version     = azurerm_key_vault_secret.database_admin[0].version
  } : null
}

output "vm_sizes" {
  description = "The cluster's VM sizes: those cluster sets, else its architecture's defaults. agents is null without an agent pool."
  value       = { system = module.vm_sizes.system, agents = module.vm_sizes.agents }
}
