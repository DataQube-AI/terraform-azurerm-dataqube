terraform {
  required_version = ">= 1.11"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 5.6" }
    random  = { source = "hashicorp/random", version = "~> 3.9" }
    time    = { source = "hashicorp/time", version = "~> 0.13" }
  }
}
