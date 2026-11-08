variable "platform" {
  description = "The platform module's outputs (pass module.platform whole)."
  type = object({
    registry           = object({ id = string, name = string, login_server = string })
    key_vault          = object({ id = string, name = string, ready_after = string })
    agent_pool_enabled = bool
    llm                = object({ endpoint = string, base_url = string, deployment = string, model = string, embeddings_deployment = string, speech_deployment = string, image_deployment = string })
    ingress = object({
      controller          = optional(string, "envoy")
      internal            = bool
      ip_address          = string
      ip_name             = string
      ip_resource_group   = string
      app_fqdn            = string
      auth_fqdn           = string
      zone_name           = string
      zone_resource_group = string
      subscription_id     = string
    })
    cert_manager_identity_client_id = string
    # null: PostgreSQL runs in the cluster.
    database = object({
      host                 = string
      name                 = string
      user                 = string
      password_secret_name = string
      password_version     = string
    })
  })
}

variable "llm_api_key" {
  description = "The model endpoint's API key (module.platform.llm_api_key)."
  type        = string
  sensitive   = true
}

variable "features" {
  description = "Product features that can be left out; pass the same value as the platform module's features. See modules/platform."
  type = object({
    web_tools         = optional(bool, true)
    speech            = optional(bool, true)
    image_generation  = optional(bool, true)
    memory_embeddings = optional(bool, true)
  })
  default = {}
}

variable "agent_token_verification" {
  description = "How the orchestrator verifies agent pods' tokens. `tokenReview` asks Kubernetes, and needs a cluster-wide permission that this module grants. `signingKeys` needs no cluster-wide permission and relies on Kubernetes' default read access to the API server's published signing keys, and on the node's clock."
  type        = string
  default     = "tokenReview"

  validation {
    condition     = contains(["signingKeys", "tokenReview"], var.agent_token_verification)
    error_message = "agent_token_verification must be signingKeys or tokenReview."
  }
}

variable "release" {
  description = <<-EOT
    Which DataQube release to run and where to get it.
    version         the release version, e.g. "0.3.0" (every image
                    is published under it)
    chart           the dataqube chart: a local path or an oci:// reference
    chart_version   chart version (for an oci:// chart)
    source_registry the vendor registry the images are imported from
    source_username the pull token's user name for source_registry (its
                    password is release_source_password); leave unset when
                    your Azure sign-in can already pull from it
    postgres_tag    the bundled PostgreSQL image's tag; defaults to version
  EOT
  type = object({
    version         = string
    chart           = string
    chart_version   = optional(string)
    source_registry = string
    source_username = optional(string)
    postgres_tag    = optional(string)
  })
  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", var.release.version))
    error_message = "release.version must be an image tag."
  }
}

variable "release_source_password" {
  description = "Password of the source registry pull token. Ephemeral: used to import the images and never stored in state."
  type        = string
  default     = null
  sensitive   = true
  ephemeral   = true
}

variable "tls" {
  description = <<-EOT
    The HTTPS certificate.
    type = "letsencrypt" (default): issued by Let's Encrypt, proved by DNS-01
      in the platform's zone; email is the ACME contact. staging = true uses
      the staging CA (untrusted certificates, generous limits) for trials.
    type = "key_vault": your own certificate, from key_vault.key_vault_id /
      certificate_name (created or imported with content type PEM, and
      exportable). It is read when applied: raise key_vault.revision after
      renewing it to deliver the new one.
  EOT
  type = object({
    type    = optional(string, "letsencrypt")
    email   = optional(string)
    staging = optional(bool, false)
    key_vault = optional(object({
      key_vault_id     = string
      certificate_name = string
      revision         = optional(number, 1)
    }))
  })
  validation {
    condition     = contains(["letsencrypt", "key_vault"], var.tls.type)
    error_message = "tls.type must be \"letsencrypt\" or \"key_vault\"."
  }
  validation {
    condition     = var.tls.type != "letsencrypt" || var.tls.email != null
    error_message = "tls.email (the ACME contact) is required for Let's Encrypt."
  }
  validation {
    condition     = var.tls.type != "key_vault" || var.tls.key_vault != null
    error_message = "tls.key_vault (key_vault_id, certificate_name) is required for your own certificate."
  }
}

variable "identity" {
  description = <<-EOT
    How people sign in.
    type = "bundled": the bundled identity provider (Authentik) at the auth
      host. admin_email is the bootstrap administrator (user name akadmin);
      organization is the first organization, administered by members of its
      dataqube-users group; deployment-admins administer the deployment.
    type = "oidc": your own OpenID Connect provider (Entra ID, Okta, ...).
      oidc.issuer / client_id / audiences / groups_claim describe it (for
      Entra ID app roles, groups_claim = "roles"); organizations map its
      group or role values to DataQube roles; deployment_admin_groups name
      the values that administer the deployment. The client secret is
      var.oidc_client_secret.
  EOT
  type = object({
    type        = optional(string, "bundled")
    admin_email = optional(string)
    organization = optional(object({
      id           = string
      display_name = string
    }), { id = "default", display_name = "Default" })
    oidc = optional(object({
      issuer                = string
      client_id             = string
      audiences             = optional(list(string), [])
      groups_claim          = optional(string, "groups")
      scopes                = optional(string, "")
      provider_name         = optional(string, "")
      client_secret_version = optional(number, 1)
    }))
    organizations = optional(list(object({
      id            = string
      display_name  = string
      role_mappings = map(list(string))
    })), [])
    deployment_admin_groups = optional(list(string), [])
  })
  validation {
    condition     = contains(["bundled", "oidc"], var.identity.type)
    error_message = "identity.type must be \"bundled\" or \"oidc\"."
  }
  validation {
    condition     = var.identity.type != "bundled" || var.identity.admin_email != null
    error_message = "identity.admin_email is required with the bundled identity provider."
  }
  validation {
    condition     = var.identity.type != "oidc" || var.identity.oidc != null
    error_message = "identity.oidc (issuer, client_id) is required when identity.type = \"oidc\"."
  }
  validation {
    condition     = var.identity.type != "oidc" || (length(var.identity.organizations) > 0 && length(var.identity.deployment_admin_groups) > 0)
    error_message = "With your own identity provider, identity.organizations and identity.deployment_admin_groups must name who may sign in and who administers the deployment."
  }
}

variable "oidc_client_secret" {
  description = "Client secret of the OIDC application (identity.type = \"oidc\"). Needed on the first apply and whenever identity.oidc.client_secret_version is raised to rotate it; it is written to Key Vault write-only and never stored in state."
  type        = string
  default     = null
  sensitive   = true
  ephemeral   = true
}

variable "credential_master_keys_previous" {
  description = "Only while rotating the credential master key: the earlier master keys, comma-separated hex, so values wrapped with them still open until `agent-orchestrator admin rewrap-secrets` re-wraps them under the current key. Written to the runtime Secret write-only (key credentialMasterKeysPrevious) and never stored in state; raise credential_master_keys_previous_revision each time it changes, including back to null."
  type        = string
  default     = null
  sensitive   = true
  ephemeral   = true
}

variable "credential_master_keys_previous_revision" {
  description = "Raise by one whenever credential_master_keys_previous changes: the runtime Secret is rewritten from Key Vault and this input only then."
  type        = number
  default     = 0
  validation {
    condition     = var.credential_master_keys_previous_revision >= 0 && floor(var.credential_master_keys_previous_revision) == var.credential_master_keys_previous_revision
    error_message = "credential_master_keys_previous_revision must be a whole number, 0 or more."
  }
}

variable "model" {
  description = "How the agents use the model."
  type = object({
    reasoning_effort      = optional(string, "medium")
    context_window_tokens = optional(number)
  })
  default = {}
}

variable "release_name" {
  description = "Helm release name; every in-cluster name derives from it."
  type        = string
  default     = "dataqube"
}

variable "namespace" {
  description = "Namespace the release is installed into."
  type        = string
  default     = "dataqube"
}

variable "envoy_gateway_version" {
  description = "Envoy Gateway controller chart version (v1.8.x is required)."
  type        = string
  default     = "v1.8.1"
}

variable "cert_manager_version" {
  description = "cert-manager chart version."
  type        = string
  default     = "v1.18.2"
}
