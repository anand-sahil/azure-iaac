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
  # Auth is controlled via environment variables:
  #   ACA runner (MSI):  ARM_USE_MSI=true + ARM_CLIENT_ID + ARM_SUBSCRIPTION_ID + ARM_TENANT_ID
  #   Local dev:         az login (auto-detected)
  #   OIDC (old):        ARM_USE_OIDC=true (if using federated credentials)
}

terraform {
  backend "azurerm" {}
}