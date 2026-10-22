# terraform-azurerm-dataqube

Terraform for installing DataQube on your own Azure subscription.

| Path | What it is |
|---|---|
| [`modules/platform`](modules/platform) | Azure: AKS (Arm64 or x86), registry, Key Vault, Azure OpenAI, DNS, identities |
| [`modules/app`](modules/app) | In the cluster: the release's images, Envoy Gateway, cert-manager, credentials, the DataQube release |
| [`examples/quickstart`](examples/quickstart) | One resource group with everything, bundled sign-in, in-cluster PostgreSQL, Let's Encrypt — start here |
| [`examples/production`](examples/production) | Your own identity provider (Entra ID …), Azure Database for PostgreSQL, and optionally private endpoints, an internal load balancer, a private cluster API and your own certificate |

The two modules are separate because Terraform's Kubernetes providers can only
be configured from a cluster that already exists: a root configuration (the
example) creates the platform, points the `kubernetes` and `helm` providers at
it, then installs the app. Work in `examples/quickstart` (or
`examples/production`) in place: the examples refer to the modules by relative
path, so a copy elsewhere must change those `source` paths.

## Requirements

- Terraform ≥ 1.11 (write-only arguments and ephemeral resources).
- Azure CLI, signed in (`az login`) as an identity with **Owner** on the
  subscription (the module creates role assignments), and `kubelogin`.
- `curl` and `jq`: the examples use them to wait until the new cluster
  accepts that sign-in.
- Regional quota for the cluster's VMs: **Arm64 Dpsv6** sizes by default (quota
  family `StandardDpsv6Family`), or **x86 Dasv6** sizes with
  `cluster = { architecture = "amd64" }` (quota family `standardDav6Family`).
  x86 needs DataQube 0.3.0 or later, the first release with x86 images.
- Azure OpenAI availability and quota in your region for the four model
  deployments the product uses, all on one account (choose others with the
  `llm` and `models` inputs; a feature switched off with `features` needs
  no deployment):

  | Use | Default model | SKU | Capacity |
  |---|---|---|---|
  | Chat (the agents) | `gpt-6-sol` | DataZoneStandard | 100 |
  | Memory search | `text-embedding-3-small` | DataZoneStandard | 50 |
  | Transcribing uploaded audio | `whisper` | Standard | 1 |
  | Image generation | `gpt-image-2.5-sunburst` | GlobalStandard | 5 |
- A DNS name you can delegate (e.g. `dataqube.example.com`), for HTTPS. The
  app requires HTTPS: browsers only allow its sign-in and session code on a
  secure origin.

## Features

Every product feature is on. To leave one out — for example no internet
access from agent sessions — set `features` in `terraform.tfvars`:

```hcl
features = {
  web_tools         = false   # agents search and fetch the public internet
  speech            = false   # transcribing uploaded audio
  image_generation  = false   # agents create and edit images
  memory_embeddings = false   # memory search by meaning (keyword search stays)
}
```

## Credentials and state

Generated credentials never enter Terraform state: they are written
write-only to Key Vault and to the cluster. The Azure OpenAI key is the one
exception (the account resource holds it). Use a remote backend that is
encrypted and access-controlled regardless — an `azurerm` backend in a storage
account with RBAC.

## Status

Both paths are verified end to end on Azure (2026-09-24). An internal load
balancer and a private cluster API cannot be reached from outside the network,
so they are covered by plan-time tests; run Terraform from inside the network
to use them.

## License

Apache License 2.0 — see [LICENSE](LICENSE).
