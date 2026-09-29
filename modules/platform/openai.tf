resource "azurerm_cognitive_account" "openai" {
  name                  = "oai-${local.base}-${local.suffix}"
  location              = azurerm_resource_group.this.location
  resource_group_name   = azurerm_resource_group.this.name
  kind                  = "OpenAI"
  sku_name              = "S0"
  custom_subdomain_name = "oai-${local.base}-${local.suffix}"
  # Only the agents call the model: through the private endpoint when set.
  public_network_access_enabled = !local.private_endpoints
  tags                          = local.tags
}

resource "azurerm_cognitive_deployment" "chat" {
  name                 = var.llm.model
  cognitive_account_id = azurerm_cognitive_account.openai.id
  model {
    format  = "OpenAI"
    name    = var.llm.model
    version = var.llm.model_version
  }
  sku {
    name     = var.llm.sku
    capacity = var.llm.capacity
  }
}

# The other models the product uses: memory embeddings, speech
# transcription and image generation, each only while its feature is on.
# Azure serialises deployment changes within one account, so each waits for
# the one before.
resource "azurerm_cognitive_deployment" "embeddings" {
  count                = var.features.memory_embeddings ? 1 : 0
  name                 = var.models.embeddings.model
  cognitive_account_id = azurerm_cognitive_account.openai.id
  model {
    format  = "OpenAI"
    name    = var.models.embeddings.model
    version = var.models.embeddings.version
  }
  sku {
    name     = var.models.embeddings.sku
    capacity = var.models.embeddings.capacity
  }
  depends_on = [azurerm_cognitive_deployment.chat]
}

resource "azurerm_cognitive_deployment" "speech" {
  count                = var.features.speech ? 1 : 0
  name                 = var.models.speech.model
  cognitive_account_id = azurerm_cognitive_account.openai.id
  model {
    format  = "OpenAI"
    name    = var.models.speech.model
    version = var.models.speech.version
  }
  sku {
    name     = var.models.speech.sku
    capacity = var.models.speech.capacity
  }
  depends_on = [azurerm_cognitive_deployment.embeddings]
}

resource "azurerm_cognitive_deployment" "image" {
  count = var.features.image_generation ? 1 : 0
  # Deployment names allow no dots.
  name                 = replace(var.models.image.model, ".", "-")
  cognitive_account_id = azurerm_cognitive_account.openai.id
  model {
    format  = "OpenAI"
    name    = var.models.image.model
    version = var.models.image.version
  }
  sku {
    name     = var.models.image.sku
    capacity = var.models.image.capacity
  }
  depends_on = [azurerm_cognitive_deployment.speech]
}
