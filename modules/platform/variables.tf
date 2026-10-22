variable "name" {
  description = "Short name for this installation, used in every Azure resource name (lowercase letters and digits, 2-12 characters), e.g. \"acme\"."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,11}$", var.name))
    error_message = "name must be 2-12 lowercase letters or digits, starting with a letter."
  }
}

variable "location" {
  description = "Azure region. The cluster's VMs (Dpsv6 for arm64, Dasv6 for amd64: cluster.architecture; quota families Dpsv6 and Dav6) and the model deployments need quota in this region."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}

variable "dns" {
  description = <<-EOT
    Where DataQube is reachable. The app is served at <app_subdomain>.<zone_name>
    and the bundled sign-in at <auth_subdomain>.<zone_name>.
    create_zone = true creates an Azure DNS zone for zone_name: delegate it
    from its parent (the name_servers output) before the first sign-in.
    create_zone = false uses an existing Azure DNS zone in
    existing_zone_resource_group_name, in this subscription.
  EOT
  type = object({
    zone_name                         = string
    create_zone                       = optional(bool, true)
    existing_zone_resource_group_name = optional(string)
    app_subdomain                     = optional(string, "app")
    auth_subdomain                    = optional(string, "auth")
  })
  validation {
    condition     = var.dns.create_zone || var.dns.existing_zone_resource_group_name != null
    error_message = "dns.existing_zone_resource_group_name is required when dns.create_zone is false."
  }
}

variable "cluster" {
  description = <<-EOT
    The AKS cluster. The system pool runs DataQube's services; an optional
    agent pool (autoscaled, tainted) runs the per-session agent pods.
    architecture is "arm64" (the default) or "amd64". It sets the default VM
    sizes: Standard_D4ps_v6 for the system pool and Standard_D8ps_v6 for the
    agent pool on arm64 (the Dpsv6 family), Standard_D4as_v6 and
    Standard_D8as_v6 on amd64 (Dasv6, whose quota family is Dav6). A size you
    set must be of the same architecture. amd64 needs DataQube 0.3.0 or later,
    the first release with x86 images.
  EOT
  type = object({
    architecture                    = optional(string, "arm64")
    kubernetes_version              = optional(string)
    sku_tier                        = optional(string, "Free")
    system_vm_size                  = optional(string)
    system_node_count               = optional(number, 2)
    availability_zones              = optional(list(string), [])
    api_server_authorized_ip_ranges = optional(list(string), [])
    agent_pool = optional(object({
      vm_size   = optional(string)
      min_count = optional(number, 1)
      max_count = optional(number, 3)
    }))
  })
  default = {}
  # The architecture and the sizes are checked in ./vm_sizes.
}

variable "llm" {
  description = <<-EOT
    The language model DataQube's agents use. type = "create" creates an
    Azure OpenAI account and its chat deployment in this resource group
    (the other models are the models input).
  EOT
  type = object({
    type          = optional(string, "create")
    model         = optional(string, "gpt-6-sol")
    model_version = optional(string, "2026-09-22")
    sku           = optional(string, "DataZoneStandard")
    capacity      = optional(number, 100)
  })
  default = {}
  validation {
    condition     = var.llm.type == "create"
    error_message = "llm.type must be \"create\" (an existing endpoint is not supported yet)."
  }
}

variable "models" {
  description = <<-EOT
    The other Azure OpenAI deployments the product uses, on the same account
    as the chat model: embeddings (memory search), speech (transcribing
    uploaded audio) and image generation. Each needs quota in your region;
    see the README.
  EOT
  type = object({
    embeddings = optional(object({
      model    = optional(string, "text-embedding-3-small")
      version  = optional(string, "1")
      sku      = optional(string, "DataZoneStandard")
      capacity = optional(number, 50)
    }), {})
    speech = optional(object({
      model    = optional(string, "whisper")
      version  = optional(string, "001")
      sku      = optional(string, "Standard")
      capacity = optional(number, 1)
    }), {})
    image = optional(object({
      model    = optional(string, "gpt-image-2.5-sunburst")
      version  = optional(string, "2026-09-08")
      sku      = optional(string, "GlobalStandard")
      capacity = optional(number, 5)
    }), {})
  })
  default = {}
}

variable "features" {
  description = <<-EOT
    Product features that can be left out. All are on by default; switching
    one off removes it from the installation (and, for a model-backed
    feature, skips its model deployment and quota).
    web_tools          agents search and fetch the public internet
    speech             transcribing uploaded audio (Whisper)
    image_generation   agents create and edit images
    memory_embeddings  searching memory by meaning (keyword search stays)
  EOT
  type = object({
    web_tools         = optional(bool, true)
    speech            = optional(bool, true)
    image_generation  = optional(bool, true)
    memory_embeddings = optional(bool, true)
  })
  default = {}
}

variable "operator_object_ids" {
  description = "Entra object IDs that administer the installation: cluster admin (Azure RBAC) and Key Vault secret access. The identity running Terraform is always included."
  type        = list(string)
  default     = []
}

variable "network" {
  description = <<-EOT
    The installation's own virtual network. null (the default) lets AKS
    manage one, which is enough for the quickstart. Required for a managed
    database, which is reachable only privately, from inside this network.
    Cluster pods use an overlay range, so only nodes take addresses here.
  EOT
  type = object({
    address_space    = optional(list(string), ["10.60.0.0/16"])
    nodes_subnet     = optional(string, "10.60.0.0/20")
    database_subnet  = optional(string, "10.60.16.0/24")
    endpoints_subnet = optional(string, "10.60.17.0/24")
    # Registry, Key Vault and Azure OpenAI reachable only through private
    # endpoints in this network; their public access is turned off.
    private_endpoints = optional(bool, false)
    # Where Terraform runs from, when it is not inside this network: allowed
    # through the Key Vault firewall and to the cluster API. Empty with
    # private endpoints means Terraform must run inside the network.
    management_ip_ranges = optional(list(string), [])
    # The cluster API has no public address at all; Terraform (and anyone
    # running kubectl) must run inside the network or a peered one.
    private_cluster = optional(bool, false)
  })
  default = null
}

variable "ingress" {
  description = <<-EOT
    How users reach DataQube. internal = false (default): a static public IP.
    internal = true: an internal load balancer at private_ip, inside
    var.network's nodes subnet — for access over VPN or ExpressRoute. The DNS
    records point at whichever address it is.
  EOT
  type = object({
    internal   = optional(bool, false)
    private_ip = optional(string)
  })
  default = {}
  validation {
    condition     = !var.ingress.internal || var.ingress.private_ip != null
    error_message = "ingress.private_ip is required with an internal ingress."
  }
  validation {
    condition     = !var.ingress.internal || var.network != null
    error_message = "An internal ingress needs var.network: its address is in the nodes subnet."
  }
}

variable "database" {
  description = <<-EOT
    Where DataQube keeps its data.
    type = "in_cluster": PostgreSQL inside the cluster (quickstart; no backups).
    type = "azure_flexible": Azure Database for PostgreSQL flexible server,
      version 18, private access only (requires var.network), with
      point-in-time restore for backup_retention_days and optional zone-
      redundant high availability.
  EOT
  type = object({
    type                         = optional(string, "in_cluster")
    sku_name                     = optional(string, "GP_Standard_D2ds_v5")
    storage_mb                   = optional(number, 65536)
    backup_retention_days        = optional(number, 14)
    geo_redundant_backup_enabled = optional(bool, false)
    high_availability            = optional(bool, false)
  })
  default = {}
  validation {
    condition     = var.database.type != "azure_flexible" || var.network != null
    error_message = "database.type = \"azure_flexible\" requires var.network: the server is reachable only from inside it."
  }
  validation {
    condition     = contains(["in_cluster", "azure_flexible"], var.database.type)
    error_message = "database.type must be \"in_cluster\" or \"azure_flexible\"."
  }
  validation {
    condition     = var.database.backup_retention_days >= 7 && var.database.backup_retention_days <= 35
    error_message = "database.backup_retention_days must be between 7 and 35."
  }
}
