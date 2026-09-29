# Cluster-wide controllers the release needs. Installed once per cluster.

resource "helm_release" "envoy_gateway" {
  name             = "eg"
  repository       = "oci://docker.io/envoyproxy"
  chart            = "gateway-helm"
  version          = var.envoy_gateway_version
  namespace        = "envoy-gateway-system"
  create_namespace = true
  wait             = true
  timeout          = 600
}

# cert-manager authenticates to Azure DNS as the platform's cert-manager
# identity, through workload identity on its own service account.
resource "helm_release" "cert_manager" {
  count            = var.tls.type == "letsencrypt" ? 1 : 0
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_version
  namespace        = "cert-manager"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [yamlencode({
    crds      = { enabled = true }
    podLabels = { "azure.workload.identity/use" = "true" }
    serviceAccount = {
      name = "cert-manager"
      annotations = {
        "azure.workload.identity/client-id" = var.platform.cert_manager_identity_client_id
      }
    }
  })]
}
