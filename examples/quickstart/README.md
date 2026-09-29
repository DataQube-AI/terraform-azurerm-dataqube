# Quickstart

Everything in one resource group: AKS on Arm64, the release imported into
your registry, Azure OpenAI, a DNS zone, sign-in through the bundled identity
provider (Authentik), in-cluster PostgreSQL and Let's Encrypt certificates.

For evaluation and pilots. It is built to be destroyed: nothing is protected
against deletion, and the in-cluster database is backed up by nothing.

## 1. Prepare

```sh
az login
az account set --subscription <subscription-id>
cp terraform.tfvars.example terraform.tfvars   # then edit it
read -rs TF_VAR_release_source_password && export TF_VAR_release_source_password   # paste the pull token password; nothing is shown
```

In `terraform.tfvars` set at least `subscription_id`, `name`, `location`,
`dns.zone_name`, `release`, `tls.email` and `identity`.

## 2. Install

```sh
terraform init
terraform apply
```

This takes about 10–15 minutes: the cluster first, then the release.

## 3. Delegate the DNS zone

The module creates an Azure DNS zone for `dns.zone_name`. Add its name servers
to the parent zone as an `NS` record:

```sh
terraform output name_servers
```

Let's Encrypt can only issue the certificate once the delegation resolves;
cert-manager keeps retrying until it does.

## 4. Check it worked

```sh
terraform output url
terraform output admin_sign_in
# Copies the password to the clipboard without printing it (macOS; on Linux
# pipe to `xclip -selection clipboard` instead):
az keyvault secret show --vault-name <password_key_vault> \
  --name <password_key_vault_secret> --query value -o tsv | pbcopy
```

Open the URL, choose **Continue with SSO** and sign in as `akadmin` with that
password. Open **Admin → Status**: it should say **Ready**, with the database
and the Kubernetes API answering. Start a thread and ask something to check
the model.

## 5. Remove it

```sh
terraform destroy
```

Also remove the `NS` delegation from the parent zone.

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

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_app"></a> [app](#module\_app) | ../../modules/app | n/a |
| <a name="module_platform"></a> [platform](#module\_platform) | ../../modules/platform | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster"></a> [cluster](#input\_cluster) | See modules/platform. | `any` | `{}` | no |
| <a name="input_dns"></a> [dns](#input\_dns) | See modules/platform: zone\_name, create\_zone, app\_subdomain, auth\_subdomain. | <pre>object({<br/>    zone_name                         = string<br/>    create_zone                       = optional(bool, true)<br/>    existing_zone_resource_group_name = optional(string)<br/>    app_subdomain                     = optional(string, "app")<br/>    auth_subdomain                    = optional(string, "auth")<br/>  })</pre> | n/a | yes |
| <a name="input_features"></a> [features](#input\_features) | See modules/platform: product features that can be left out (web\_tools, speech, image\_generation, memory\_embeddings); all on by default. | `any` | `{}` | no |
| <a name="input_identity"></a> [identity](#input\_identity) | Bootstrap administrator email and first organization. | `any` | n/a | yes |
| <a name="input_llm"></a> [llm](#input\_llm) | See modules/platform. | `any` | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region with Arm64 (Dpsv6) VMs and model quota. | `string` | n/a | yes |
| <a name="input_model"></a> [model](#input\_model) | Reasoning effort and context window. | `any` | `{}` | no |
| <a name="input_models"></a> [models](#input\_models) | See modules/platform: the embeddings, speech and image model deployments. | `any` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Short installation name (2-12 lowercase letters/digits). | `string` | n/a | yes |
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