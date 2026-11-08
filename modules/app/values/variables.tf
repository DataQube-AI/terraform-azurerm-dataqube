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

variable "agent_token_verification" {
  description = "How the orchestrator verifies agent pods' tokens (modules/app agent_token_verification)."
  type        = string
  default     = "tokenReview"

  validation {
    condition     = contains(["signingKeys", "tokenReview"], var.agent_token_verification)
    error_message = "agent_token_verification must be signingKeys or tokenReview."
  }
}

variable "features" {
  description = "Product features that can be left out (modules/platform features)."
  type = object({
    web_tools         = bool
    speech            = bool
    image_generation  = bool
    memory_embeddings = bool
  })
}

variable "release" {
  description = <<-EOT
    Which DataQube release to run and where to get it.
    version         the release version, e.g. "0.2.1" (every image
                    is published under it)
    chart           the dataqube chart: a local path or an oci:// reference
    chart_version   chart version (for an oci:// chart)
    source_registry the vendor registry the images are imported from
    source_username the pull token's user name for source_registry (its
                    password is release_source_password); leave unset when
                    your Azure sign-in can already pull from it
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

variable "secret_names" {
  description = "Names of the Kubernetes Secrets modules/app created (null where a mode has none)."
  type = object({
    runtime              = string
    llm                  = string
    app_postgresql       = optional(string)
    authentik_runtime    = optional(string)
    authentik_postgresql = optional(string)
  })
}
