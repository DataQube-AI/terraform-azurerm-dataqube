# modules/app

Everything inside the cluster, installed with the `helm` and `kubernetes`
providers against the cluster `modules/platform` created:

1. **Release images** are copied into the installation's registry with
   `az acr import` (needs the Azure CLI, signed in).
2. **Controllers**: Envoy Gateway (v1.8) and cert-manager (workload identity
   for DNS-01).
3. **Credentials**: generated ephemerally, written *write-only* to Key Vault,
   and delivered to Kubernetes Secrets write-only from an ephemeral Key Vault
   read. None reaches Terraform state; Key Vault stays the source of truth.
   The model key is the exception: the Azure OpenAI account resource carries
   it, so it is in state (protect the backend).
4. **The `dataqube` release chart**, with values built from these inputs:
   bundled Authentik sign-in at the auth host, in-cluster PostgreSQL, Let's
   Encrypt certificates, the model endpoint, and the first organization.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 5.6 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3.3 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 3.2 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.9 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~> 5.6 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 3.3 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~> 3.2 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_values"></a> [values](#module\_values) | ./values | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_key_vault_secret.generated](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_key_vault_secret.oidc_client_secret](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [helm_release.cert_manager](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.dataqube](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.envoy_gateway](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace_v1.release](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_secret_v1.app_postgresql](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.authentik_postgresql](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.authentik_runtime](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.llm](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.runtime](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.tls](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [terraform_data.image](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.key_vault_ready](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cert_manager_version"></a> [cert\_manager\_version](#input\_cert\_manager\_version) | cert-manager chart version. | `string` | `"v1.18.2"` | no |
| <a name="input_envoy_gateway_version"></a> [envoy\_gateway\_version](#input\_envoy\_gateway\_version) | Envoy Gateway controller chart version (v1.8.x is required). | `string` | `"v1.8.1"` | no |
| <a name="input_features"></a> [features](#input\_features) | Product features that can be left out; pass the same value as the platform module's features. See modules/platform. | <pre>object({<br/>    web_tools         = optional(bool, true)<br/>    speech            = optional(bool, true)<br/>    image_generation  = optional(bool, true)<br/>    memory_embeddings = optional(bool, true)<br/>  })</pre> | `{}` | no |
| <a name="input_identity"></a> [identity](#input\_identity) | How people sign in.<br/>type = "bundled": the bundled identity provider (Authentik) at the auth<br/>  host. admin\_email is the bootstrap administrator (user name akadmin);<br/>  organization is the first organization, administered by members of its<br/>  dataqube-users group; deployment-admins administer the deployment.<br/>type = "oidc": your own OpenID Connect provider (Entra ID, Okta, ...).<br/>  oidc.issuer / client\_id / audiences / groups\_claim describe it (for<br/>  Entra ID app roles, groups\_claim = "roles"); organizations map its<br/>  group or role values to DataQube roles; deployment\_admin\_groups name<br/>  the values that administer the deployment. The client secret is<br/>  var.oidc\_client\_secret. | <pre>object({<br/>    type        = optional(string, "bundled")<br/>    admin_email = optional(string)<br/>    organization = optional(object({<br/>      id           = string<br/>      display_name = string<br/>    }), { id = "default", display_name = "Default" })<br/>    oidc = optional(object({<br/>      issuer                = string<br/>      client_id             = string<br/>      audiences             = optional(list(string), [])<br/>      groups_claim          = optional(string, "groups")<br/>      scopes                = optional(string, "")<br/>      provider_name         = optional(string, "")<br/>      client_secret_version = optional(number, 1)<br/>    }))<br/>    organizations = optional(list(object({<br/>      id            = string<br/>      display_name  = string<br/>      role_mappings = map(list(string))<br/>    })), [])<br/>    deployment_admin_groups = optional(list(string), [])<br/>  })</pre> | n/a | yes |
| <a name="input_llm_api_key"></a> [llm\_api\_key](#input\_llm\_api\_key) | The model endpoint's API key (module.platform.llm\_api\_key). | `string` | n/a | yes |
| <a name="input_model"></a> [model](#input\_model) | How the agents use the model. | <pre>object({<br/>    reasoning_effort      = optional(string, "medium")<br/>    context_window_tokens = optional(number)<br/>  })</pre> | `{}` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace the release is installed into. | `string` | `"dataqube"` | no |
| <a name="input_oidc_client_secret"></a> [oidc\_client\_secret](#input\_oidc\_client\_secret) | Client secret of the OIDC application (identity.type = "oidc"). Needed on the first apply and whenever identity.oidc.client\_secret\_version is raised to rotate it; it is written to Key Vault write-only and never stored in state. | `string` | `null` | no |
| <a name="input_platform"></a> [platform](#input\_platform) | The platform module's outputs (pass module.platform whole). | <pre>object({<br/>    registry           = object({ id = string, name = string, login_server = string })<br/>    key_vault          = object({ id = string, name = string, ready_after = string })<br/>    agent_pool_enabled = bool<br/>    llm                = object({ endpoint = string, base_url = string, deployment = string, model = string, embeddings_deployment = string, speech_deployment = string, image_deployment = string })<br/>    ingress = object({<br/>      internal            = bool<br/>      ip_address          = string<br/>      ip_name             = string<br/>      ip_resource_group   = string<br/>      app_fqdn            = string<br/>      auth_fqdn           = string<br/>      zone_name           = string<br/>      zone_resource_group = string<br/>      subscription_id     = string<br/>    })<br/>    cert_manager_identity_client_id = string<br/>    # null: PostgreSQL runs in the cluster.<br/>    database = object({<br/>      host                 = string<br/>      name                 = string<br/>      user                 = string<br/>      password_secret_name = string<br/>      password_version     = string<br/>    })<br/>  })</pre> | n/a | yes |
| <a name="input_release"></a> [release](#input\_release) | Which DataQube release to run and where to get it.<br/>version         the release version, e.g. "0.2.1" (every image<br/>                is published under it)<br/>chart           the dataqube chart: a local path or an oci:// reference<br/>chart\_version   chart version (for an oci:// chart)<br/>source\_registry the vendor registry the images are imported from<br/>source\_username the pull token's user name for source\_registry (its<br/>                password is release\_source\_password); leave unset when<br/>                your Azure sign-in can already pull from it<br/>postgres\_tag    the bundled PostgreSQL image's tag; defaults to version | <pre>object({<br/>    version         = string<br/>    chart           = string<br/>    chart_version   = optional(string)<br/>    source_registry = string<br/>    source_username = optional(string)<br/>    postgres_tag    = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | Helm release name; every in-cluster name derives from it. | `string` | `"dataqube"` | no |
| <a name="input_release_source_password"></a> [release\_source\_password](#input\_release\_source\_password) | Password of the source registry pull token. Ephemeral: used to import the images and never stored in state. | `string` | `null` | no |
| <a name="input_tls"></a> [tls](#input\_tls) | The HTTPS certificate.<br/>type = "letsencrypt" (default): issued by Let's Encrypt, proved by DNS-01<br/>  in the platform's zone; email is the ACME contact. staging = true uses<br/>  the staging CA (untrusted certificates, generous limits) for trials.<br/>type = "key\_vault": your own certificate, from key\_vault.key\_vault\_id /<br/>  certificate\_name (created or imported with content type PEM, and<br/>  exportable). It is read when applied: raise key\_vault.revision after<br/>  renewing it to deliver the new one. | <pre>object({<br/>    type    = optional(string, "letsencrypt")<br/>    email   = optional(string)<br/>    staging = optional(bool, false)<br/>    key_vault = optional(object({<br/>      key_vault_id     = string<br/>      certificate_name = string<br/>      revision         = optional(number, 1)<br/>    }))<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_admin_sign_in"></a> [admin\_sign\_in](#output\_admin\_sign\_in) | The bundled identity provider's bootstrap administrator: sign in as akadmin with the password in this Key Vault secret (null with your own identity provider). |
| <a name="output_url"></a> [url](#output\_url) | Where DataQube is served. |
<!-- END_TF_DOCS -->