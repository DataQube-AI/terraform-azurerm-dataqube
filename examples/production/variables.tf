variable "subscription_id" {
  description = "Azure subscription to install into."
  type        = string
}

variable "name" {
  description = "Short installation name (2-12 lowercase letters/digits)."
  type        = string
}

variable "location" {
  description = "Azure region with Arm64 (Dpsv6) VMs and model quota."
  type        = string
}

variable "dns" {
  description = "See modules/platform: zone_name, create_zone, app_subdomain, auth_subdomain."
  type = object({
    zone_name                         = string
    create_zone                       = optional(bool, true)
    existing_zone_resource_group_name = optional(string)
    app_subdomain                     = optional(string, "app")
    auth_subdomain                    = optional(string, "auth")
  })
}

variable "cluster" {
  description = "See modules/platform."
  type        = any
  default     = {}
}

variable "llm" {
  description = "See modules/platform."
  type        = any
  default     = {}
}

variable "models" {
  description = "See modules/platform: the embeddings, speech and image model deployments."
  type        = any
  default     = {}
}

variable "features" {
  description = "See modules/platform: product features that can be left out (web_tools, speech, image_generation, memory_embeddings); all on by default."
  type        = any
  default     = {}
}

variable "release" {
  description = "See modules/app: version, chart, chart_version, source_registry, source_username."
  type        = any
}

variable "release_source_password" {
  description = "Pull token password for release.source_registry (unset when your Azure sign-in can pull). Ephemeral: never stored in state."
  type        = string
  default     = null
  sensitive   = true
  ephemeral   = true
}

variable "tls" {
  description = "See modules/app: Let's Encrypt (email, staging) or your own certificate from Key Vault (type = \"key_vault\")."
  type        = any
}

variable "identity" {
  description = "See modules/app: type = \"oidc\" with oidc, organizations and deployment_admin_groups (or \"bundled\")."
  type        = any
}

variable "oidc_client_secret" {
  description = "Your identity provider's client secret: set TF_VAR_oidc_client_secret on the first apply and when rotating. Never stored in state."
  type        = string
  default     = null
  sensitive   = true
  ephemeral   = true
}

variable "model" {
  description = "Reasoning effort and context window."
  type        = any
  default     = {}
}

variable "operator_object_ids" {
  description = "Extra Entra object IDs that administer the installation."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags on every resource."
  type        = map(string)
  default     = {}
}

variable "network" {
  description = "See modules/platform: address ranges, private_endpoints, management_ip_ranges, private_cluster."
  type        = any
  default     = {}
}

variable "ingress" {
  description = "See modules/platform: internal = true with private_ip for an internal load balancer."
  type        = any
  default     = {}
}

variable "database" {
  description = "See modules/platform. Production uses Azure Database for PostgreSQL."
  type        = any
  default     = { type = "azure_flexible" }
}
