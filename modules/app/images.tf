locals {
  managed_database = var.platform.database != null
  images = merge({
    "agent-orchestrator" = var.release.version
    "agentcore-web"      = var.release.version
    "agent-core"         = var.release.version
    "agent-kernel"       = var.release.version
  }, local.managed_database ? {} : { "postgres" = coalesce(var.release.postgres_tag, var.release.version) })
}

# Copy the release into the installation's own registry, so the running
# installation never pulls from the vendor. Requires the Azure CLI, signed in
# as the identity running Terraform (it needs AcrPush-level rights on the
# target registry, which Owner/Contributor include).
resource "terraform_data" "image" {
  for_each = local.images

  triggers_replace = {
    registry = var.platform.registry.name
    source   = var.release.source_registry
    image    = "dataqube/${each.key}:${each.value}"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      # The empty-array expansion below is safe under set -u on bash 3.2
      # (macOS) as well as bash 4+.
      auth=()
      if [[ -n "$${SOURCE_USERNAME:-}" ]]; then
        # The Azure CLI reads an argument given as @- from its standard input:
        # the password never appears on a command line.
        auth=(--username "$SOURCE_USERNAME" --password @-)
      fi
      printf '%s' "$${SOURCE_PASSWORD:-}" | az acr import --name "$TARGET_REGISTRY" --force \
        --source "$SOURCE_REGISTRY/$IMAGE" --image "$IMAGE" $${auth[@]+"$${auth[@]}"}
    EOT
    environment = {
      TARGET_REGISTRY = var.platform.registry.name
      SOURCE_REGISTRY = var.release.source_registry
      IMAGE           = "dataqube/${each.key}:${each.value}"
      SOURCE_USERNAME = var.release.source_username == null ? "" : var.release.source_username
      SOURCE_PASSWORD = var.release_source_password == null ? "" : var.release_source_password
    }
    quiet = true
  }
}
