terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.41.0"
    }
  }
}

provider "azurerm" {
  features {}
  # Auth via Azure CLI (auto-detected):
  #   ACA runner:  az login --identity in entrypoint.sh (managed identity)
  #   Local dev:   az login
}

terraform {
  backend "azurerm" {}
}