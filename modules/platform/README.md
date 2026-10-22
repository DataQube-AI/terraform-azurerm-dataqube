# modules/platform

The Azure side of a DataQube installation, in one resource group:

- **AKS** on Arm64 (Dpsv6) or x86 (Dasv6) VMs, as `cluster.architecture` says: Entra ID + Azure RBAC only (no local accounts),
  workload identity, Azure CNI Overlay with Cilium. A system pool runs the
  services; an optional autoscaled agent pool (label and taint
  `dataqube.dev/pool=agents`) runs per-session agent pods.
- **Container registry** the release is imported into; the kubelet pulls with
  `AcrPull`, so no image pull secret exists.
- **Key Vault** (RBAC) for every generated credential.
- **Azure OpenAI** account with four deployments: chat, embeddings (memory
  search), speech and image generation, each skipped when its feature is off.
- **DNS**: a zone (created, or an existing one), the ingress public IP and
  `A` records for the app and sign-in hosts, and a cert-manager identity that
  may edit that zone only (DNS-01 through workload identity).

The identity running Terraform, plus `operator_object_ids`, get AKS RBAC
Cluster Admin and Key Vault Secrets Officer.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 5.6 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.9 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.13 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~> 5.6 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.9 |
| <a name="provider_time"></a> [time](#provider\_time) | ~> 0.13 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_vm_sizes"></a> [vm\_sizes](#module\_vm\_sizes) | ./vm_sizes | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_cognitive_account.openai](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cognitive_account) | resource |
| [azurerm_cognitive_deployment.chat](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cognitive_deployment) | resource |
| [azurerm_cognitive_deployment.embeddings](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cognitive_deployment) | resource |
| [azurerm_cognitive_deployment.image](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cognitive_deployment) | resource |
| [azurerm_cognitive_deployment.speech](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cognitive_deployment) | resource |
| [azurerm_container_registry.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry) | resource |
| [azurerm_dns_a_record.app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/dns_a_record) | resource |
| [azurerm_dns_a_record.auth](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/dns_a_record) | resource |
| [azurerm_dns_zone.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/dns_zone) | resource |
| [azurerm_federated_identity_credential.cert_manager](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/federated_identity_credential) | resource |
| [azurerm_key_vault.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) | resource |
| [azurerm_key_vault_secret.database_admin](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_kubernetes_cluster.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster) | resource |
| [azurerm_kubernetes_cluster_node_pool.agents](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster_node_pool) | resource |
| [azurerm_postgresql_flexible_server.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server) | resource |
| [azurerm_postgresql_flexible_server_configuration.extensions](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server_configuration) | resource |
| [azurerm_postgresql_flexible_server_database.dataqube](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server_database) | resource |
| [azurerm_private_dns_zone.database](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) | resource |
| [azurerm_private_dns_zone.private_link](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) | resource |
| [azurerm_private_dns_zone_virtual_network_link.database](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link) | resource |
| [azurerm_private_dns_zone_virtual_network_link.private_link](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link) | resource |
| [azurerm_private_endpoint.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_public_ip.ingress](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.cert_manager_dns](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.cluster_admin](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.cluster_network](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.key_vault_officer](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.kubelet_acr_pull](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_subnet.database](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet.endpoints](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet.nodes](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_user_assigned_identity.cert_manager](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [time_sleep.cluster_rbac](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.key_vault_rbac](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_dns_zone.existing](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/dns_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster"></a> [cluster](#input\_cluster) | The AKS cluster. The system pool runs DataQube's services; an optional<br/>agent pool (autoscaled, tainted) runs the per-session agent pods.<br/>architecture is "arm64" (the default) or "amd64". It sets the default VM<br/>sizes: Standard\_D4ps\_v6 for the system pool and Standard\_D8ps\_v6 for the<br/>agent pool on arm64 (the Dpsv6 family), Standard\_D4as\_v6 and<br/>Standard\_D8as\_v6 on amd64 (Dasv6, whose quota family is Dav6). A size you<br/>set must be of the same architecture. amd64 needs DataQube 0.3.0 or later,<br/>the first release with x86 images. | <pre>object({<br/>    architecture                    = optional(string, "arm64")<br/>    kubernetes_version              = optional(string)<br/>    sku_tier                        = optional(string, "Free")<br/>    system_vm_size                  = optional(string)<br/>    system_node_count               = optional(number, 2)<br/>    availability_zones              = optional(list(string), [])<br/>    api_server_authorized_ip_ranges = optional(list(string), [])<br/>    agent_pool = optional(object({<br/>      vm_size   = optional(string)<br/>      min_count = optional(number, 1)<br/>      max_count = optional(number, 3)<br/>    }))<br/>  })</pre> | `{}` | no |
| <a name="input_database"></a> [database](#input\_database) | Where DataQube keeps its data.<br/>type = "in\_cluster": PostgreSQL inside the cluster (quickstart; no backups).<br/>type = "azure\_flexible": Azure Database for PostgreSQL flexible server,<br/>  version 18, private access only (requires var.network), with<br/>  point-in-time restore for backup\_retention\_days and optional zone-<br/>  redundant high availability. | <pre>object({<br/>    type                         = optional(string, "in_cluster")<br/>    sku_name                     = optional(string, "GP_Standard_D2ds_v5")<br/>    storage_mb                   = optional(number, 65536)<br/>    backup_retention_days        = optional(number, 14)<br/>    geo_redundant_backup_enabled = optional(bool, false)<br/>    high_availability            = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_dns"></a> [dns](#input\_dns) | Where DataQube is reachable. The app is served at <app\_subdomain>.<zone\_name><br/>and the bundled sign-in at <auth\_subdomain>.<zone\_name>.<br/>create\_zone = true creates an Azure DNS zone for zone\_name: delegate it<br/>from its parent (the name\_servers output) before the first sign-in.<br/>create\_zone = false uses an existing Azure DNS zone in<br/>existing\_zone\_resource\_group\_name, in this subscription. | <pre>object({<br/>    zone_name                         = string<br/>    create_zone                       = optional(bool, true)<br/>    existing_zone_resource_group_name = optional(string)<br/>    app_subdomain                     = optional(string, "app")<br/>    auth_subdomain                    = optional(string, "auth")<br/>  })</pre> | n/a | yes |
| <a name="input_features"></a> [features](#input\_features) | Product features that can be left out. All are on by default; switching<br/>one off removes it from the installation (and, for a model-backed<br/>feature, skips its model deployment and quota).<br/>web\_tools          agents search and fetch the public internet<br/>speech             transcribing uploaded audio (Whisper)<br/>image\_generation   agents create and edit images<br/>memory\_embeddings  searching memory by meaning (keyword search stays) | <pre>object({<br/>    web_tools         = optional(bool, true)<br/>    speech            = optional(bool, true)<br/>    image_generation  = optional(bool, true)<br/>    memory_embeddings = optional(bool, true)<br/>  })</pre> | `{}` | no |
| <a name="input_ingress"></a> [ingress](#input\_ingress) | How users reach DataQube. internal = false (default): a static public IP.<br/>internal = true: an internal load balancer at private\_ip, inside<br/>var.network's nodes subnet — for access over VPN or ExpressRoute. The DNS<br/>records point at whichever address it is. | <pre>object({<br/>    internal   = optional(bool, false)<br/>    private_ip = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_llm"></a> [llm](#input\_llm) | The language model DataQube's agents use. type = "create" creates an<br/>Azure OpenAI account and its chat deployment in this resource group<br/>(the other models are the models input). | <pre>object({<br/>    type          = optional(string, "create")<br/>    model         = optional(string, "gpt-6-sol")<br/>    model_version = optional(string, "2026-09-22")<br/>    sku           = optional(string, "DataZoneStandard")<br/>    capacity      = optional(number, 100)<br/>  })</pre> | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region. The cluster's VMs (Dpsv6 for arm64, Dasv6 for amd64: cluster.architecture; quota families Dpsv6 and Dav6) and the model deployments need quota in this region. | `string` | n/a | yes |
| <a name="input_models"></a> [models](#input\_models) | The other Azure OpenAI deployments the product uses, on the same account<br/>as the chat model: embeddings (memory search), speech (transcribing<br/>uploaded audio) and image generation. Each needs quota in your region;<br/>see the README. | <pre>object({<br/>    embeddings = optional(object({<br/>      model    = optional(string, "text-embedding-3-small")<br/>      version  = optional(string, "1")<br/>      sku      = optional(string, "DataZoneStandard")<br/>      capacity = optional(number, 50)<br/>    }), {})<br/>    speech = optional(object({<br/>      model    = optional(string, "whisper")<br/>      version  = optional(string, "001")<br/>      sku      = optional(string, "Standard")<br/>      capacity = optional(number, 1)<br/>    }), {})<br/>    image = optional(object({<br/>      model    = optional(string, "gpt-image-2.5-sunburst")<br/>      version  = optional(string, "2026-09-08")<br/>      sku      = optional(string, "GlobalStandard")<br/>      capacity = optional(number, 5)<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Short name for this installation, used in every Azure resource name (lowercase letters and digits, 2-12 characters), e.g. "acme". | `string` | n/a | yes |
| <a name="input_network"></a> [network](#input\_network) | The installation's own virtual network. null (the default) lets AKS<br/>manage one, which is enough for the quickstart. Required for a managed<br/>database, which is reachable only privately, from inside this network.<br/>Cluster pods use an overlay range, so only nodes take addresses here. | <pre>object({<br/>    address_space    = optional(list(string), ["10.60.0.0/16"])<br/>    nodes_subnet     = optional(string, "10.60.0.0/20")<br/>    database_subnet  = optional(string, "10.60.16.0/24")<br/>    endpoints_subnet = optional(string, "10.60.17.0/24")<br/>    # Registry, Key Vault and Azure OpenAI reachable only through private<br/>    # endpoints in this network; their public access is turned off.<br/>    private_endpoints = optional(bool, false)<br/>    # Where Terraform runs from, when it is not inside this network: allowed<br/>    # through the Key Vault firewall and to the cluster API. Empty with<br/>    # private endpoints means Terraform must run inside the network.<br/>    management_ip_ranges = optional(list(string), [])<br/>    # The cluster API has no public address at all; Terraform (and anyone<br/>    # running kubectl) must run inside the network or a peered one.<br/>    private_cluster = optional(bool, false)<br/>  })</pre> | `null` | no |
| <a name="input_operator_object_ids"></a> [operator\_object\_ids](#input\_operator\_object\_ids) | Entra object IDs that administer the installation: cluster admin (Azure RBAC) and Key Vault secret access. The identity running Terraform is always included. | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_agent_pool_enabled"></a> [agent\_pool\_enabled](#output\_agent\_pool\_enabled) | Whether session agent pods have their own pool (label and taint dataqube.dev/pool=agents). |
| <a name="output_cert_manager_identity_client_id"></a> [cert\_manager\_identity\_client\_id](#output\_cert\_manager\_identity\_client\_id) | Client ID of the identity cert-manager uses for DNS-01. |
| <a name="output_cluster"></a> [cluster](#output\_cluster) | How to reach the cluster's API (Entra ID authentication; no local accounts). host and cluster\_ca\_certificate are known only once the operators' grants have reached the cluster. |
| <a name="output_database"></a> [database](#output\_database) | The managed database (null when PostgreSQL runs in the cluster). The admin password is in Key Vault under password\_secret\_name. |
| <a name="output_ingress"></a> [ingress](#output\_ingress) | The public address and names the gateway serves. |
| <a name="output_key_vault"></a> [key\_vault](#output\_key\_vault) | The Key Vault holding the installation's generated credentials. ready\_after is a dependency handle: write secrets only after it. |
| <a name="output_llm"></a> [llm](#output\_llm) | The model endpoints the product uses: chat, embeddings, speech and image generation, all on one Azure OpenAI account. A switched-off feature's deployment is null. |
| <a name="output_llm_api_key"></a> [llm\_api\_key](#output\_llm\_api\_key) | The Azure OpenAI account key. Sensitive: held in state because the account resource carries it. |
| <a name="output_name_servers"></a> [name\_servers](#output\_name\_servers) | Delegate dns.zone\_name to these from its parent zone (only when the module created the zone). |
| <a name="output_registry"></a> [registry](#output\_registry) | The installation's container registry. |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | The installation's resource group. |
| <a name="output_vm_sizes"></a> [vm\_sizes](#output\_vm\_sizes) | The cluster's VM sizes: those cluster sets, else its architecture's defaults. agents is null without an agent pool. |
<!-- END_TF_DOCS -->