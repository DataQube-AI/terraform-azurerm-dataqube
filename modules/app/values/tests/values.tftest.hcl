# The release values each mode produces. Pure module: no providers.

variables {
  platform = {
    registry           = { id = "acr-id", name = "acrtest", login_server = "acrtest.azurecr.io" }
    key_vault          = { id = "kv-id", name = "kv", ready_after = "ready" }
    agent_pool_enabled = true
    llm = {
      endpoint              = "https://oai.example/", base_url = "https://oai.example/openai/v1", deployment = "gpt-6-sol", model = "gpt-6-sol"
      embeddings_deployment = "text-embedding-3-small", speech_deployment = "whisper", image_deployment = "gpt-image-2-5-sunburst"
    }
    ingress = {
      internal  = false, ip_address = "20.0.0.1", ip_name = "pip", ip_resource_group = "mc-rg"
      app_fqdn  = "app.acme.example", auth_fqdn = "auth.acme.example"
      zone_name = "acme.example", zone_resource_group = "rg", subscription_id = "sub"
    }
    cert_manager_identity_client_id = "cm-client"
    database                        = null
  }
  release      = { version = "79075766", chart = "chart", source_registry = "vendor.azurecr.io" }
  tls          = { email = "ops@acme.example" }
  release_name = "dataqube"
  secret_names = {
    runtime              = "dataqube-runtime"
    llm                  = "dataqube-llm"
    app_postgresql       = "dataqube-app-postgresql"
    authentik_runtime    = "dataqube-authentik-runtime"
    authentik_postgresql = "dataqube-authentik-postgresql"
  }
  identity = { admin_email = "ops@acme.example", organization = { id = "acme", display_name = "Acme" } }
  features = { web_tools = true, speech = true, image_generation = true, memory_embeddings = true }
}

run "bundled_identity_runs_authentik_at_the_auth_host" {
  command = plan
  assert {
    condition     = yamldecode(output.documents[1])["dataqube-core"].oidc.issuer == "https://auth.acme.example/application/o/agent-core-web/"
    error_message = "the bundled issuer is the public auth host"
  }
  assert {
    condition     = yamldecode(output.documents[1])["dataqube-core"].oidc.jwksUrl == "http://dataqube-authentik-server/application/o/agent-core-web/jwks/"
    error_message = "signing keys are fetched in-cluster, from this release's Authentik"
  }
  assert {
    condition     = yamldecode(output.documents[1])["dataqube-infra"].authentik.authentik.existingSecret.secretName == "dataqube-authentik-runtime"
    error_message = "Authentik reads its whole runtime configuration from the module's secret"
  }
  assert {
    condition     = contains(yamldecode(output.documents[0])["dataqube-infra"].certManager.certificate.dnsNames, "auth.acme.example")
    error_message = "the certificate covers the auth host"
  }
  assert {
    condition     = yamldecode(output.documents[0])["dataqube-core"].agentCore.nodeSelector == { "dataqube.dev/pool" = "agents" }
    error_message = "session pods go to the agent pool"
  }
}

run "own_identity_provider_turns_authentik_off_and_maps_orgs" {
  command = plan
  variables {
    identity = {
      type = "oidc"
      oidc = {
        issuer       = "https://login.microsoftonline.com/tenant/v2.0"
        client_id    = "client-id"
        audiences    = ["client-id", "api://client-id"]
        groups_claim = "roles"
      }
      organizations           = [{ id = "acme", display_name = "Acme", role_mappings = { admin = ["DataQube.Admin"], analyst = ["DataQube.Analyst"] } }]
      deployment_admin_groups = ["DataQube.DeploymentAdmin"]
    }
    secret_names = { runtime = "dataqube-runtime", llm = "dataqube-llm", app_postgresql = "dataqube-app-postgresql" }
  }
  assert {
    condition     = yamldecode(output.documents[1])["dataqube-infra"].authentik.enabled == false && yamldecode(output.documents[1])["dataqube-infra"].authentikApp.enabled == false
    error_message = "no bundled identity provider runs"
  }
  assert {
    condition     = yamldecode(output.documents[1])["dataqube-core"].oidc.issuer == "https://login.microsoftonline.com/tenant/v2.0" && yamldecode(output.documents[1])["dataqube-core"].oidc.jwksUrl == ""
    error_message = "the issuer is yours, and its signing keys are discovered from it"
  }
  assert {
    condition     = yamldecode(output.documents[1])["dataqube-core"].oidc.groupsClaim == "roles" && yamldecode(output.documents[1])["dataqube-core"].oidc.audiences == ["client-id", "api://client-id"]
    error_message = "the claim and audiences come from the configuration"
  }
  assert {
    condition     = yamldecode(output.documents[1])["dataqube-core"].bootstrap.orgs[0].roleMappings.analyst == ["DataQube.Analyst"]
    error_message = "organizations map the provider's values to roles"
  }
  assert {
    condition     = yamldecode(output.documents[1])["dataqube-core"].bootstrap.deploymentAdminGroups == ["DataQube.DeploymentAdmin"]
    error_message = "deployment administrators come from the configuration"
  }
  assert {
    condition     = yamldecode(output.documents[0])["dataqube-infra"].certManager.certificate.dnsNames == ["app.acme.example"]
    error_message = "the certificate covers only the app host"
  }
}

run "own_identity_provider_requires_who_may_sign_in" {
  command = plan
  variables {
    identity = {
      type = "oidc"
      oidc = { issuer = "https://idp.example", client_id = "c" }
    }
  }
  expect_failures = [var.identity]
}

run "bundled_identity_requires_an_admin_email" {
  command = plan
  variables {
    identity = { organization = { id = "acme", display_name = "Acme" } }
  }
  expect_failures = [var.identity]
}

run "managed_database_turns_the_bundled_one_off" {
  command = plan
  variables {
    platform = {
      registry           = { id = "acr-id", name = "acrtest", login_server = "acrtest.azurecr.io" }
      key_vault          = { id = "kv-id", name = "kv", ready_after = "ready" }
      agent_pool_enabled = false
      llm                = { endpoint = "https://oai.example/", base_url = "https://oai.example/openai/v1", deployment = "gpt-6-sol", model = "gpt-6-sol", embeddings_deployment = "text-embedding-3-small", speech_deployment = "whisper", image_deployment = "gpt-image-2-5-sunburst" }
      ingress = {
        internal  = false, ip_address = "20.0.0.1", ip_name = "pip", ip_resource_group = "mc-rg"
        app_fqdn  = "app.acme.example", auth_fqdn = "auth.acme.example"
        zone_name = "acme.example", zone_resource_group = "rg", subscription_id = "sub"
      }
      cert_manager_identity_client_id = "cm-client"
      database = {
        host                 = "psql.private.postgres.database.azure.com", name = "dataqube", user = "dataqube_admin"
        password_secret_name = "database-admin-password", password_version = "v1"
      }
    }
  }
  assert {
    condition     = yamldecode(output.documents[0])["dataqube-infra"].postgresql.enabled == false
    error_message = "the bundled database is off"
  }
  assert {
    condition     = yamldecode(output.documents[0])["dataqube-core"].agentCore.nodeSelector == {} && yamldecode(output.documents[0])["dataqube-core"].agentCore.tolerations == []
    error_message = "without an agent pool, session pods may run anywhere"
  }
}

run "internal_ingress_uses_an_internal_load_balancer" {
  command = plan
  variables {
    platform = {
      registry           = { id = "acr-id", name = "acrtest", login_server = "acrtest.azurecr.io" }
      key_vault          = { id = "kv-id", name = "kv", ready_after = "ready" }
      agent_pool_enabled = false
      llm                = { endpoint = "https://oai.example/", base_url = "https://oai.example/openai/v1", deployment = "gpt-6-sol", model = "gpt-6-sol", embeddings_deployment = "text-embedding-3-small", speech_deployment = "whisper", image_deployment = "gpt-image-2-5-sunburst" }
      ingress = {
        internal  = true, ip_address = "10.60.0.250", ip_name = null, ip_resource_group = "mc-rg"
        app_fqdn  = "app.acme.example", auth_fqdn = "auth.acme.example"
        zone_name = "acme.example", zone_resource_group = "rg", subscription_id = "sub"
      }
      cert_manager_identity_client_id = "cm-client"
      database                        = null
    }
  }
  assert {
    condition     = yamldecode(output.documents[0])["dataqube-infra"].gateway.envoyProxy.annotations["service.beta.kubernetes.io/azure-load-balancer-internal"] == "true"
    error_message = "the gateway's load balancer is internal"
  }
  assert {
    condition     = yamldecode(output.documents[0])["dataqube-infra"].gateway.envoyProxy.loadBalancerIP == "10.60.0.250"
    error_message = "it takes the configured private address"
  }
  assert {
    condition     = !contains(keys(yamldecode(output.documents[0])["dataqube-infra"].gateway.envoyProxy.annotations), "service.beta.kubernetes.io/azure-pip-name")
    error_message = "no public IP is attached"
  }
}

run "own_certificate_turns_cert_manager_off" {
  command = plan
  variables {
    tls = { type = "key_vault", key_vault = { key_vault_id = "kv-id", certificate_name = "dataqube" } }
  }
  assert {
    condition     = yamldecode(output.documents[0])["dataqube-infra"].certManager.enabled == false
    error_message = "no certificate is requested from Let's Encrypt"
  }
  assert {
    condition     = yamldecode(output.documents[0])["dataqube-infra"].gateway.tls.secretName == "dataqube-tls"
    error_message = "the gateway serves the secret the module fills from Key Vault"
  }
}

run "lets_encrypt_requires_a_contact" {
  command = plan
  variables {
    tls = { type = "letsencrypt" }
  }
  expect_failures = [var.tls]
}

run "every_product_feature_gets_its_model_endpoint" {
  command = plan

  assert {
    condition = yamldecode(output.documents[0])["dataqube-core"].orchestrator.memoryEmbeddings == {
      enabled = true, provider = "azure_openai", baseUrl = "https://oai.example/openai/v1", model = "text-embedding-3-small"
    }
    error_message = "embeddings must use the v1 surface and the embeddings deployment"
  }
  assert {
    condition = yamldecode(output.documents[0])["dataqube-core"].orchestrator.speech == {
      enabled = true, baseUrl = "https://oai.example", deployment = "whisper"
    }
    error_message = "speech must address the account root and the whisper deployment"
  }
  assert {
    condition = yamldecode(output.documents[0])["dataqube-core"].agentCore.imageGeneration == {
      enabled    = true
      baseUrl    = "https://oai.example"
      deployment = "gpt-image-2-5-sunburst"
      apiKey     = { secretName = "dataqube-llm", secretKey = "apiKey" }
    }
    error_message = "image generation must address the account root with the shared key"
  }
  # The release still pins its orchestrator image alongside.
  assert {
    condition     = yamldecode(output.documents[0])["dataqube-core"].orchestrator.image.tag == "79075766"
    error_message = "the orchestrator image tag must survive the endpoint merge"
  }
}

run "every_product_feature_is_on_unless_switched_off" {
  command = plan
  assert {
    condition     = yamldecode(output.documents[0])["dataqube-core"].agentCore.kernel.web.enabled == true
    error_message = "web tools are on by default"
  }
}

run "a_switched_off_feature_leaves_the_installation" {
  command = plan
  variables {
    features = { web_tools = false, speech = false, image_generation = false, memory_embeddings = false }
    platform = {
      registry           = { id = "acr-id", name = "acrtest", login_server = "acrtest.azurecr.io" }
      key_vault          = { id = "kv-id", name = "kv", ready_after = "ready" }
      agent_pool_enabled = false
      llm = {
        endpoint              = "https://oai.example/", base_url = "https://oai.example/openai/v1", deployment = "gpt-6-sol", model = "gpt-6-sol"
        embeddings_deployment = null, speech_deployment = null, image_deployment = null
      }
      ingress = {
        internal  = false, ip_address = "20.0.0.1", ip_name = "pip", ip_resource_group = "mc-rg"
        app_fqdn  = "app.acme.example", auth_fqdn = "auth.acme.example"
        zone_name = "acme.example", zone_resource_group = "rg", subscription_id = "sub"
      }
      cert_manager_identity_client_id = "cm-client"
      database                        = null
    }
  }
  assert {
    condition     = yamldecode(output.documents[0])["dataqube-core"].agentCore.kernel.web.enabled == false
    error_message = "web tools off"
  }
  assert {
    condition     = yamldecode(output.documents[0])["dataqube-core"].orchestrator.speech == { enabled = false }
    error_message = "speech off, with no endpoint"
  }
  assert {
    condition     = yamldecode(output.documents[0])["dataqube-core"].agentCore.imageGeneration == { enabled = false }
    error_message = "image generation off, with no endpoint"
  }
  assert {
    condition     = yamldecode(output.documents[0])["dataqube-core"].orchestrator.memoryEmbeddings == { enabled = false, passiveQuery = { enabled = false } }
    error_message = "embeddings and passive query off together (the chart refuses passive query without embeddings)"
  }
}

run "bundled_postgres_uses_the_release_version_by_default" {
  command = plan
  # A release publishes its PostgreSQL image under the release version; a
  # fixed tag here once named an image the release registry never had.
  assert {
    condition     = yamldecode(output.documents[0])["dataqube-infra"].postgresql.image.tag == "79075766"
    error_message = "without postgres_tag, the bundled PostgreSQL image is the release version"
  }
}

run "bundled_postgres_tag_can_be_overridden" {
  command = plan
  variables {
    release = { version = "79075766", chart = "chart", source_registry = "vendor.azurecr.io", postgres_tag = "custom" }
  }
  assert {
    condition     = yamldecode(output.documents[0])["dataqube-infra"].postgresql.image.tag == "custom"
    error_message = "postgres_tag overrides the release version"
  }
}
