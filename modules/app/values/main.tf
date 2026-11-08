# The dataqube chart's values, as a pure function of the inputs: no
# providers, no effects, so every mode is testable at plan time
# (tests/values.tftest.hcl). modules/app passes the result to helm_release.

locals {
  managed_database = var.platform.database != null
  bundled_identity = var.identity.type == "bundled"

  app  = var.platform.ingress.app_fqdn
  auth = var.platform.ingress.auth_fqdn
  tls  = "${var.release_name}-tls"
  # Speech and image generation address the account root; chat and
  # embeddings the OpenAI v1 surface.
  openai_root = trimsuffix(var.platform.llm.endpoint, "/")

  # Each model-backed feature: its endpoint when on, or the switch that
  # leaves it out. The two shapes differ, so they are picked by key rather
  # than with a conditional.
  switch = { for name, on in var.features : name => on ? "on" : "off" }
  feature_values = {
    memory_embeddings = {
      on = {
        enabled  = true
        provider = "azure_openai"
        baseUrl  = var.platform.llm.base_url
        model    = var.platform.llm.embeddings_deployment
      }
      # The chart refuses passive query without embeddings.
      off = { enabled = false, passiveQuery = { enabled = false } }
    }
    speech = {
      on  = { enabled = true, baseUrl = local.openai_root, deployment = var.platform.llm.speech_deployment }
      off = { enabled = false }
    }
    image_generation = {
      on = {
        enabled    = true
        baseUrl    = local.openai_root
        deployment = var.platform.llm.image_deployment
        apiKey     = { secretName = var.secret_names.llm, secretKey = "apiKey" }
      }
      off = { enabled = false }
    }
  }

  # Session agent pods go to the agent pool when there is one.
  agent_scheduling = {
    nodeSelector = var.platform.agent_pool_enabled ? { "dataqube.dev/pool" = "agents" } : {}
    tolerations  = var.platform.agent_pool_enabled ? [{ key = "dataqube.dev/pool", operator = "Equal", value = "agents", effect = "NoSchedule" }] : []
  }

  # How users reach the release: the Envoy Gateway the chart deploys, or an
  # Application Gateway that AGIC programs from the chart's Ingress objects.
  # The shapes differ, so they are picked by key, as features are.
  entries = {
    envoy = {
      infra_gateway = {
        envoyProxy = {
          enabled        = true
          loadBalancerIP = var.platform.ingress.ip_address
          # Internal: a private address in the nodes subnet. Public: the
          # platform's static public IP.
          annotations = var.platform.ingress.internal ? {
            "service.beta.kubernetes.io/azure-load-balancer-internal"        = "true"
            "service.beta.kubernetes.io/azure-load-balancer-internal-subnet" = "snet-nodes"
            } : {
            "service.beta.kubernetes.io/azure-pip-name"                     = var.platform.ingress.ip_name
            "service.beta.kubernetes.io/azure-load-balancer-resource-group" = var.platform.ingress.ip_resource_group
          }
        }
        tls       = { enabled = true, secretName = local.tls }
        hostnames = { app = local.app, authentik = local.auth }
      }
      core      = { gateway = { hostname = local.app, tls = { enabled = true, secretName = local.tls } } }
      authentik = {}
    }
    application_gateway = {
      infra_gateway = { enabled = false }
      core = {
        gateway = { enabled = false }
        ingress = {
          enabled     = true
          className   = local.ingress_class
          host        = local.app
          tls         = { enabled = true, secretName = local.tls }
          annotations = { "appgw.ingress.kubernetes.io/ssl-redirect" = "true" }
          # Sessions stream for up to an hour, and uploads are large. AGIC
          # would otherwise probe the readiness path, which also checks the
          # database.
          api = { annotations = {
            "appgw.ingress.kubernetes.io/request-timeout"   = "3600"
            "appgw.ingress.kubernetes.io/health-probe-path" = "/api/orchestrator/health"
          } }
          web = { annotations = {
            "appgw.ingress.kubernetes.io/request-timeout"   = "3600"
            "appgw.ingress.kubernetes.io/health-probe-path" = "/api/health"
          } }
        }
      }
      # The bundled Authentik's own Ingress (the upstream chart renders it),
      # on the auth host, under the same certificate.
      authentik = {
        server = {
          ingress = {
            enabled          = true
            ingressClassName = local.ingress_class
            hosts            = [local.auth]
            tls              = [{ secretName = local.tls, hosts = [local.auth] }]
            annotations = {
              "appgw.ingress.kubernetes.io/ssl-redirect"      = "true"
              "appgw.ingress.kubernetes.io/health-probe-path" = "/-/health/live/"
            }
          }
        }
      }
    }
  }
  ingress_class = "azure-application-gateway"
  entry         = local.entries[var.platform.ingress.controller]

  values = {
    "dataqube-infra" = {
      # Off when the platform provides a managed database; the other keys
      # are then unused.
      postgresql = {
        enabled = !local.managed_database
        image   = { repository = "${var.platform.registry.login_server}/dataqube/postgres", tag = coalesce(var.release.postgres_tag, var.release.version) }
        auth    = { existingSecret = var.secret_names.app_postgresql }
        storage = { storageClassName = "managed-csi" }
      }
      gateway = local.entry.infra_gateway
      # Let's Encrypt only; your own certificate arrives as the TLS secret.
      certManager = {
        enabled = var.tls.type == "letsencrypt"
        issuer = {
          email  = var.tls.email
          server = var.tls.staging ? "https://acme-staging-v02.api.letsencrypt.org/directory" : "https://acme-v02.api.letsencrypt.org/directory"
        }
        azureDNS = {
          subscriptionID          = var.platform.ingress.subscription_id
          resourceGroupName       = var.platform.ingress.zone_resource_group
          hostedZoneName          = var.platform.ingress.zone_name
          managedIdentityClientID = var.platform.cert_manager_identity_client_id
        }
        certificate = {
          name       = local.tls
          secretName = local.tls
          commonName = local.app
          dnsNames   = local.bundled_identity ? [local.app, local.auth] : [local.app]
        }
      }
    }
    "dataqube-core" = merge({
      imageRegistry = var.platform.registry.login_server
      secrets       = { existingSecret = var.secret_names.runtime }
      orchestrator = {
        image = { tag = var.release.version }
        # Every product feature is on in the chart; these are the endpoints
        # it needs, or the switch that leaves a feature out. Their keys fall
        # back to the chat model's.
        memoryEmbeddings = local.feature_values.memory_embeddings[local.switch.memory_embeddings]
        speech           = local.feature_values.speech[local.switch.speech]
      }
      web = { image = { tag = var.release.version }, nextauthUrl = "https://${local.app}" }
      agentCore = merge({
        tokenVerification = var.agent_token_verification
        image             = { tag = var.release.version }
        kernel            = { image = { tag = var.release.version }, web = { enabled = var.features.web_tools } }
        llm = merge({
          provider        = "azure_openai"
          model           = var.platform.llm.model
          deployment      = var.platform.llm.deployment
          baseUrl         = var.platform.llm.base_url
          auth            = "api_key"
          apiKeyHeader    = "api-key"
          reasoningEffort = var.model.reasoning_effort
          apiKey = {
            secretName = var.secret_names.llm
            secretKey  = "apiKey"
            envName    = "AZURE_OPENAI_API_KEY"
          }
        }, var.model.context_window_tokens == null ? {} : { contextWindowTokens = tostring(var.model.context_window_tokens) })
        imageGeneration = local.feature_values.image_generation[local.switch.image_generation]
      }, local.agent_scheduling)
    }, local.entry.core)
  }
}

# Identity differs in shape between the two modes, so it is its own values
# document (Helm merges them in order).
locals {
  bundled_identity_values = {
    "dataqube-infra" = {
      authentikApp = {
        clientSecret    = ""
        clientSecretEnv = "AUTHENTIK_DATAQUBE_OIDC_CLIENT_SECRET"
        redirectUris    = ["https://${local.app}/api/auth/callback/oidc"]
      }
      authentikBootstrap = { enabled = false }
      authentik = merge({
        authentik = { existingSecret = { secretName = var.secret_names.authentik_runtime } }
        global    = { env = [] }
        postgresql = {
          auth = {
            existingSecret = var.secret_names.authentik_postgresql
            secretKeys     = { adminPasswordKey = "postgres-password", userPasswordKey = "password" }
          }
        }
      }, local.entry.authentik)
    }
    "dataqube-core" = {
      oidc = {
        # Tokens carry the public issuer; the orchestrator fetches signing
        # keys in-cluster.
        issuer  = "https://${local.auth}/application/o/agent-core-web/"
        jwksUrl = "http://${var.release_name}-authentik-server/application/o/agent-core-web/jwks/"
      }
      bootstrap = {
        orgs = [{
          id           = var.identity.organization.id
          displayName  = var.identity.organization.display_name
          roleMappings = { admin = ["dataqube-users"] }
        }]
        deploymentAdminGroups = ["deployment-admins"]
      }
    }
  }

  # Your identity provider: no bundled one runs, and every endpoint comes
  # from the issuer's discovery document.
  oidc_identity_values = local.bundled_identity ? null : {
    "dataqube-infra" = {
      authentik    = { enabled = false }
      authentikApp = { enabled = false }
    }
    "dataqube-core" = {
      oidc = {
        issuer       = var.identity.oidc.issuer
        jwksUrl      = ""
        clientId     = var.identity.oidc.client_id
        audiences    = var.identity.oidc.audiences
        groupsClaim  = var.identity.oidc.groups_claim
        scopes       = var.identity.oidc.scopes
        providerName = var.identity.oidc.provider_name
      }
      bootstrap = {
        orgs = [for org in var.identity.organizations : {
          id           = org.id
          displayName  = org.display_name
          roleMappings = org.role_mappings
        }]
        deploymentAdminGroups = var.identity.deployment_admin_groups
      }
    }
  }

  identity_values = local.bundled_identity ? yamlencode(local.bundled_identity_values) : yamlencode(local.oidc_identity_values)
}
