# Production

The quickstart's shape, hardened where it matters first:

- **Your own identity provider** (OpenID Connect: Microsoft Entra ID, Okta,
  Keycloak …). No bundled identity provider runs.
- **Azure Database for PostgreSQL** flexible server (PostgreSQL 18) with
  private access only, from the installation's own virtual network, and
  point-in-time restore (`database.backup_retention_days`, up to 35 days).
  Zone-redundant high availability with `database.high_availability`.
- Key Vault kept recoverable after a destroy (soft delete is not purged).
- Optionally **private endpoints** for the registry, Key Vault and Azure OpenAI
  (`network.private_endpoints`, with `network.management_ip_ranges` for where
  Terraform runs), an **internal load balancer** (`ingress.internal`), a
  **private cluster API** (`network.private_cluster`), and **your own
  certificate** from Key Vault (`tls.type = "key_vault"`).

## Region

The region needs Arm64 **Dpsv6** VMs (or x86 **Dasv6** with `cluster.architecture = "amd64"`) *and* PostgreSQL flexible server for your
subscription. Some subscriptions are restricted from creating flexible
servers in some regions; check before you start:

```sh
az postgres flexible-server list-skus -l <region> --query "[0].reason"
```

`null` means you can create one there.

## Microsoft Entra ID

Your Entra administrator registers DataQube once:

1. **App registrations → New registration.** Redirect URI (Web):
   `https://<app host>/api/auth/callback/oidc`.
2. **Expose an API**: Application ID URI `api://<client-id>`, and a scope
   named `access`.
3. **App roles**: `DataQube.Admin`, `DataQube.Analyst`, `DataQube.Viewer`,
   `DataQube.DeploymentAdmin` (allowed member types: Users/Groups). Assign
   users or groups to them under **Enterprise applications → Users and
   groups**.
4. **Certificates & secrets → New client secret.** This is
   `TF_VAR_oidc_client_secret`.

Then set `identity` as in `terraform.tfvars.example`: `groups_claim = "roles"`
maps the app roles, and `deployment_admin_groups` names who administers the
deployment.

## Install and check it worked

```sh
cp terraform.tfvars.example terraform.tfvars   # then edit it
read -rs TF_VAR_release_source_password && export TF_VAR_release_source_password   # paste the pull token password; nothing is shown
read -rs TF_VAR_oidc_client_secret && export TF_VAR_oidc_client_secret   # paste the client secret
terraform init
terraform apply
```

Delegate the DNS zone (`terraform output name_servers`), open `terraform
output url`, sign in with an account holding `DataQube.DeploymentAdmin`, and
check **Admin → Status** says Ready and **Admin → Identity** shows your issuer
and a matching administrator value.

The client secret is needed again only to rotate it: raise
`identity.oidc.client_secret_version` and apply with the new one.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 5.6 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3.3 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 3.2 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.9 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.13 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_time"></a> [time](#provider\_time) | ~> 0.13 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_app"></a> [app](#module\_app) | ../../modules/app | n/a |
| <a name="module_platform"></a> [platform](#module\_platform) | ../../modules/platform | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [time_sleep.cluster_access](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster"></a> [cluster](#input\_cluster) | See modules/platform. | `any` | `{}` | no |
| <a name="input_database"></a> [database](#input\_database) | See modules/platform. Production uses Azure Database for PostgreSQL. | `any` | <pre>{<br/>  "type": "azure_flexible"<br/>}</pre> | no |
| <a name="input_dns"></a> [dns](#input\_dns) | See modules/platform: zone\_name, create\_zone, app\_subdomain, auth\_subdomain. | <pre>object({<br/>    zone_name                         = string<br/>    create_zone                       = optional(bool, true)<br/>    existing_zone_resource_group_name = optional(string)<br/>    app_subdomain                     = optional(string, "app")<br/>    auth_subdomain                    = optional(string, "auth")<br/>  })</pre> | n/a | yes |
| <a name="input_features"></a> [features](#input\_features) | See modules/platform: product features that can be left out (web\_tools, speech, image\_generation, memory\_embeddings); all on by default. | `any` | `{}` | no |
| <a name="input_identity"></a> [identity](#input\_identity) | See modules/app: type = "oidc" with oidc, organizations and deployment\_admin\_groups (or "bundled"). | `any` | n/a | yes |
| <a name="input_ingress"></a> [ingress](#input\_ingress) | See modules/platform: internal = true with private\_ip for an internal load balancer. | `any` | `{}` | no |
| <a name="input_llm"></a> [llm](#input\_llm) | See modules/platform. | `any` | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region with quota for the cluster's VMs (Dpsv6 sizes for arm64, Dasv6 for amd64; quota families StandardDpsv6Family and standardDav6Family) and the models. | `string` | n/a | yes |
| <a name="input_model"></a> [model](#input\_model) | Reasoning effort and context window. | `any` | `{}` | no |
| <a name="input_models"></a> [models](#input\_models) | See modules/platform: the embeddings, speech and image model deployments. | `any` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Short installation name (2-12 lowercase letters/digits). | `string` | n/a | yes |
| <a name="input_network"></a> [network](#input\_network) | See modules/platform: address ranges, private\_endpoints, management\_ip\_ranges, private\_cluster. | `any` | `{}` | no |
| <a name="input_oidc_client_secret"></a> [oidc\_client\_secret](#input\_oidc\_client\_secret) | Your identity provider's client secret: set TF\_VAR\_oidc\_client\_secret on the first apply and when rotating. Never stored in state. | `string` | `null` | no |
| <a name="input_operator_object_ids"></a> [operator\_object\_ids](#input\_operator\_object\_ids) | Extra Entra object IDs that administer the installation. | `list(string)` | `[]` | no |
| <a name="input_release"></a> [release](#input\_release) | See modules/app: version, chart, chart\_version, source\_registry, source\_username. | `any` | n/a | yes |
| <a name="input_release_source_password"></a> [release\_source\_password](#input\_release\_source\_password) | Pull token password for release.source\_registry (unset when your Azure sign-in can pull). Ephemeral: never stored in state. | `string` | `null` | no |
| <a name="input_subscription_id"></a> [subscription\_id](#input\_subscription\_id) | Azure subscription to install into. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags on every resource. | `map(string)` | `{}` | no |
| <a name="input_tls"></a> [tls](#input\_tls) | See modules/app: Let's Encrypt (email, staging) or your own certificate from Key Vault (type = "key\_vault"). | `any` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_admin_sign_in"></a> [admin\_sign\_in](#output\_admin\_sign\_in) | Sign in as akadmin. Copy the password without printing it: az keyvault secret show --vault-name <vault> --name <secret> --query value -o tsv \| pbcopy |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The AKS cluster, for kubectl: az aks get-credentials --resource-group <resource\_group\_name> --name <cluster\_name>, then kubelogin convert-kubeconfig -l azurecli. |
| <a name="output_name_servers"></a> [name\_servers](#output\_name\_servers) | Delegate dns.zone\_name to these from its parent zone. |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | Everything Azure-side is in this resource group (plus the AKS node group). |
| <a name="output_url"></a> [url](#output\_url) | Open this once the certificate is issued. |
<!-- END_TF_DOCS -->