# Behind Azure Application Gateway

The [quickstart](../quickstart), with an **Azure Application Gateway v2**
(Standard_v2) in front instead of the Envoy Gateway, as a platform team's
gateway would be. The AKS add-on AGIC (Application Gateway Ingress
Controller) programs the gateway from the release's Ingress objects. Sign-in
is through the bundled identity provider (Authentik), served through the same
gateway.

It needs DataQube 0.3.2 or later: the first release whose orchestrator answers
`/api/orchestrator` itself, so the gateway forwards paths unchanged, and whose
chart can serve the bundled Authentik through an Ingress.

DataQube installs this example on every release candidate, on both
architectures, before the release is published.

## What the gateway does for DataQube

| | Set by | Value |
|---|---|---|
| Routes | the release's Ingress objects | `/api/orchestrator` → orchestrator (port 8080), `/` → web (port 3000), on the app host; `/` → Authentik on the auth host. No rewrite |
| TLS | cert-manager (Let's Encrypt, DNS-01) | one certificate for both hosts; AGIC installs it on the gateway, and HTTP redirects to HTTPS |
| Timeouts | `appgw.ingress.kubernetes.io/request-timeout` | 3600 s on both routes: sessions stream over WebSockets for up to an hour, and uploads are large |
| Health probes | `appgw.ingress.kubernetes.io/health-probe-path` | `/api/orchestrator/health`, `/api/health` and Authentik's `/-/health/live/`. Not the readiness paths, which also check the databases |
| WebSockets, body size | the gateway | WebSockets are always on; without WAF, Standard_v2 inspects no request bodies, and its upload limit is far above DataQube's 256 MB |

Everything the gateway must allow, whichever gateway it is, is on the
[Use your own gateway or ingress](https://docs.data-qube.com/install/own-gateway)
page.

### If your platform team runs the gateway

- **AGIC takes over the gateway it's given.** The add-on rewrites the
  gateway's whole configuration. A gateway that other applications share
  needs AGIC installed with Helm in shared mode instead. DataQube's side is
  the same either way: `dataqube-core.ingress` and
  `dataqube-infra.authentik.server.ingress`.
- **A gateway configured by hand** needs the same two routes, timeouts and
  probes, pointed at the two Services.
- **Network security group.** This example attaches none to the gateway's
  subnet. One that is attached must allow `GatewayManager` on ports
  65200–65535, `AzureLoadBalancer`, and ports 80 and 443 from your users.
- **Sign-in goes back through the gateway.** The web server reaches the auth
  host at the gateway's public address, from the cluster's outbound address.
  A listener restricted by source address must allow the cluster's.
- **WAF.** This example uses Standard_v2. On WAF_v2, raise the upload limit
  for the upload paths and add exclusions for DataQube's requests, which carry
  SQL and code.

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

This takes about 20 minutes: the gateway, then the cluster, then the release.
AGIC needs a few more minutes after that to program the gateway.

## 3. Delegate the DNS zone

The module creates an Azure DNS zone for `dns.zone_name`, with the app and
auth hosts pointing at the gateway. Add its name servers to the parent zone as
an `NS` record:

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
password. Start a thread and ask something: the answer streams through the
gateway.

If the page doesn't load, check the gateway's view of the backends:

```sh
az network application-gateway show-backend-health \
  --resource-group "$(terraform output -raw resource_group_name)" \
  --name "agw-dataqube-<name>" -o table
```

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
| <a name="input_application_gateway"></a> [application\_gateway](#input\_application\_gateway) | See modules/platform (ingress.application\_gateway): the gateway's subnet in that network (/24 or smaller) and its maximum capacity. | `any` | `{}` | no |
| <a name="input_cluster"></a> [cluster](#input\_cluster) | See modules/platform. | `any` | `{}` | no |
| <a name="input_dns"></a> [dns](#input\_dns) | See modules/platform: zone\_name, create\_zone, app\_subdomain, auth\_subdomain. | <pre>object({<br/>    zone_name                         = string<br/>    create_zone                       = optional(bool, true)<br/>    existing_zone_resource_group_name = optional(string)<br/>    app_subdomain                     = optional(string, "app")<br/>    auth_subdomain                    = optional(string, "auth")<br/>  })</pre> | n/a | yes |
| <a name="input_features"></a> [features](#input\_features) | See modules/platform: product features that can be left out (web\_tools, speech, image\_generation, memory\_embeddings); all on by default. | `any` | `{}` | no |
| <a name="input_identity"></a> [identity](#input\_identity) | Bootstrap administrator email and first organization. | `any` | n/a | yes |
| <a name="input_llm"></a> [llm](#input\_llm) | See modules/platform. | `any` | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region with quota for the cluster's VMs (Dpsv6 sizes for arm64, Dasv6 for amd64; quota families StandardDpsv6Family and standardDav6Family) and the models. | `string` | n/a | yes |
| <a name="input_model"></a> [model](#input\_model) | Reasoning effort and context window. | `any` | `{}` | no |
| <a name="input_models"></a> [models](#input\_models) | See modules/platform: the embeddings, speech and image model deployments. | `any` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Short installation name (2-12 lowercase letters/digits). | `string` | n/a | yes |
| <a name="input_network"></a> [network](#input\_network) | See modules/platform: the installation's own virtual network, which the gateway shares with the nodes. The defaults are enough. | `any` | `{}` | no |
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
