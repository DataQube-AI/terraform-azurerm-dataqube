terraform {
  required_version = ">= 1.11"
  required_providers {
    azurerm    = { source = "hashicorp/azurerm", version = "~> 5.6" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 3.2" }
    helm       = { source = "hashicorp/helm", version = "~> 3.3" }
    random     = { source = "hashicorp/random", version = "~> 3.9" }
  }
}
