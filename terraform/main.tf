terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.11.0"
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

  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_B2s"
  }

  identity {
    type = "SystemAssigned"
  }
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.main.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.main.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
  }
}

resource "helm_release" "sealed_secrets" {
  name       = "sealed-secrets"
  namespace  = "kube-system"
  repository = "https://bitnami-labs.github.io/sealed-secrets"
  chart      = "sealed-secrets"
  version    = "2.17.2"
}

resource "kubernetes_namespace" "devops_demo" {
  metadata {
    name = "devops-demo"
  }
}

resource "helm_release" "devops_infra" {
  name       = "devops-infra"
  namespace  = "devops-demo"
  chart      = "../devops-infra" 
  values     = [file("../devops-infra/values.yaml")]

  depends_on = [helm_release.sealed_secrets, kubernetes_namespace.devops_demo]
}

resource "kubernetes_manifest" "sqlserver_sealedsecret" {
  manifest = yamldecode(file("${path.module}/../secrets/sqlserver-sealedsecret.yaml"))
  depends_on = [helm_release.sealed_secrets, kubernetes_namespace.devops_demo]
}

resource "kubernetes_manifest" "webapp_sqlserver_sealedsecret" {
  manifest = yamldecode(file("${path.module}/../secrets/webapp-sqlserver-sealedsecret.yaml"))
  depends_on = [helm_release.sealed_secrets, kubernetes_namespace.devops_demo]
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.14.4"
  create_namespace = true
  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "kubernetes_manifest" "letsencrypt_clusterissuer" {
  manifest = yamldecode(file("${path.module}/../secrets/letsencrypt-clusterissuer.yaml"))
  depends_on = [helm_release.cert_manager]
}

resource "kubernetes_manifest" "webapp_certificate" {
  manifest = yamldecode(file("${path.module}/../secrets/webapp-certificate.yaml"))
  depends_on = [helm_release.cert_manager, kubernetes_namespace.devops_demo]
}