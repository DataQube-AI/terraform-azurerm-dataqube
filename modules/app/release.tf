locals {
  app = var.platform.ingress.app_fqdn
}

module "values" {
  source = "./values"

  platform     = var.platform
  release      = var.release
  tls          = var.tls
  identity     = var.identity
  model        = var.model
  features     = var.features
  release_name = var.release_name

  agent_token_verification = var.agent_token_verification

  secret_names = {
    runtime              = kubernetes_secret_v1.runtime.metadata[0].name
    llm                  = kubernetes_secret_v1.llm.metadata[0].name
    app_postgresql       = one(kubernetes_secret_v1.app_postgresql[*].metadata[0].name)
    authentik_runtime    = one(kubernetes_secret_v1.authentik_runtime[*].metadata[0].name)
    authentik_postgresql = one(kubernetes_secret_v1.authentik_postgresql[*].metadata[0].name)
  }
}

resource "helm_release" "dataqube" {
  name              = local.r
  namespace         = kubernetes_namespace_v1.release.metadata[0].name
  chart             = var.release.chart
  version           = var.release.chart_version
  dependency_update = true
  wait              = true
  # A failed install is removed rather than left behind: otherwise the next
  # apply cannot reuse the release name and a re-run cannot recover.
  atomic  = true
  timeout = 1200
  values  = module.values.documents

  depends_on = [
    helm_release.envoy_gateway,
    helm_release.cert_manager,
    kubernetes_secret_v1.tls,
    terraform_data.image,
  ]
}
