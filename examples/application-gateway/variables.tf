variable "subscription_id" {
  description = "Azure subscription to install into."
  type        = string
}

variable "name" {
  description = "Short installation name (2-12 lowercase letters/digits)."
  type        = string
}

variable "location" {
  description = "Azure region with quota for the cluster's VMs (Dpsv6 sizes for arm64, Dasv6 for amd64; quota families StandardDpsv6Family and standardDav6Family) and the models."
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

variable "agent_token_verification" {
  description = "See modules/app: how the orchestrator verifies agent pods' tokens, tokenReview or signingKeys (no cluster-wide permission)."
  type        = string
  default     = "tokenReview"
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
  description = "Bootstrap administrator email and first organization."
  type        = any
}

variable "model" {
  description = "Reasoning effort and context window."
  type        = any
  default     = {}
}

variable "network" {
  description = "See modules/platform: the installation's own virtual network, which the gateway shares with the nodes. The defaults are enough."
  type        = any
  default     = {}
}

variable "application_gateway" {
  description = "See modules/platform (ingress.application_gateway): the gateway's subnet in that network (/24 or smaller) and its maximum capacity."
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
