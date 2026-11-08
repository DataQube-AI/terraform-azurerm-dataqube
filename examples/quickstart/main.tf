# DataQube quickstart: one resource group with everything in it — AKS (Arm64 or x86),
# a registry holding the release, Key Vault, Azure OpenAI, a DNS zone, the
# bundled sign-in (Authentik), in-cluster PostgreSQL and Let's Encrypt
# certificates. See README.md for the steps.

terraform {
  required_version = ">= 1.11"
  required_providers {
    azurerm    = { source = "hashicorp/azurerm", version = "~> 5.6" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 3.2" }
    helm       = { source = "hashicorp/helm", version = "~> 3.3" }
    random     = { source = "hashicorp/random", version = "~> 3.9" }
    time       = { source = "hashicorp/time", version = "~> 0.13" }
  }
  # Configure a remote, encrypted, access-controlled backend (e.g. azurerm)
  # before a real installation; see README.md.
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {
    key_vault {
      # A quickstart is disposable: destroying it frees the vault's name.
      purge_soft_delete_on_destroy = true
    }
  }
}

module "platform" {
  source = "../../modules/platform"

  name     = var.name
  location = var.location
  dns      = var.dns
  cluster  = var.cluster
  llm      = var.llm
  models   = var.models
  features = var.features
  tags     = var.tags

  operator_object_ids = var.operator_object_ids
}

# The cluster has no local accounts: Terraform reaches it with your Azure CLI
# sign-in through kubelogin (Azure RBAC Cluster Admin, granted by the module).
locals {
  kube_exec = {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    # 6dae42f8-… is the AKS AAD server application, the same in every tenant.
    args = ["get-token", "--login", "azurecli", "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630"]
  }
  kube = {
    host                   = time_sleep.cluster_access.triggers.host
    cluster_ca_certificate = base64decode(time_sleep.cluster_access.triggers.cluster_ca_certificate)
    exec                   = local.kube_exec
  }
}

# The grant reaches the cluster's API minutes after it exists, so the providers
# get the cluster only once it accepts that sign-in: on creation, this waits
# until it does (up to 10 minutes; another apply carries on).
resource "time_sleep" "cluster_access" {
  create_duration = "0s"
  triggers = {
    host                   = module.platform.cluster.host
    cluster_ca_certificate = module.platform.cluster.cluster_ca_certificate
  }
  provisioner "local-exec" {
    command = "sh ${path.module}/../../modules/platform/wait-for-cluster-access.sh"
    environment = {
      HOST          = self.triggers.host
      CA            = base64decode(self.triggers.cluster_ca_certificate)
      TOKEN_COMMAND = join(" ", concat([local.kube_exec.command], local.kube_exec.args))
    }
  }
}

provider "kubernetes" {
  host                   = local.kube.host
  cluster_ca_certificate = local.kube.cluster_ca_certificate
  exec {
    api_version = local.kube.exec.api_version
    command     = local.kube.exec.command
    args        = local.kube.exec.args
  }
}

provider "helm" {
  kubernetes = {
    host                   = local.kube.host
    cluster_ca_certificate = local.kube.cluster_ca_certificate
    exec                   = local.kube.exec
  }
  # The release chart is pulled from the vendor registry with the pull token.
  # Provider configuration takes the ephemeral password, so it is never
  # stored in state.
  # Only when the password is given: `terraform destroy` needs no chart pull,
  # so it runs without the pull token.
  registries = startswith(try(var.release.chart, ""), "oci://") && try(var.release.source_username, null) != null && var.release_source_password != null ? [{
    url      = "oci://${var.release.source_registry}"
    username = var.release.source_username
    password = var.release_source_password
  }] : []
}

module "app" {
  source = "../../modules/app"

  platform    = module.platform
  llm_api_key = module.platform.llm_api_key

  release                  = var.release
  release_source_password  = var.release_source_password
  tls                      = var.tls
  identity                 = var.identity
  model                    = var.model
  features                 = var.features
  agent_token_verification = var.agent_token_verification

  # The cluster-admin grant must exist before Terraform talks to the cluster.
  depends_on = [module.platform]
}
