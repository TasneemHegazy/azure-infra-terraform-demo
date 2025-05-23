   terraform {
     required_providers {
       azurerm = {
         source  = "hashicorp/azurerm"
         version = "~> 3.0"
       }
     }
     required_version = ">= 1.0.0"
   }

   provider "azurerm" {
     features {}
   }

   resource "azurerm_resource_group" "main" {
     name     = var.resource_group_name
     location = var.location
   }

   resource "azurerm_kubernetes_cluster" "main" {
     name                = "devops-demo-aks"
     location            = azurerm_resource_group.main.location
     resource_group_name = azurerm_resource_group.main.name
     dns_prefix          = "devopsdemo"

     sku_tier = "Free"

     default_node_pool {
       name       = "default"
       node_count = 1
       vm_size    = "Standard_B2s"
     }

     identity {
       type = "SystemAssigned"
     }
   }