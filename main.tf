terraform {
    backend "azurerm" {
      resource_group_name  = "RateMyBeer_Infrastructure"
      storage_account_name = "ratemybeerstorage"
      container_name       = "terraformstate"
      key                  = "trichling.4719.meinapetitocluster.tfstate"
    }

    required_providers {
      azurerm = {
        source = "hashicorp/azurerm"
        version = ">= 2.78"
      }

      helm = {
          source = "hashicorp/helm"
          version = ">= 2.2"
      }
    }
}

provider "azurerm" {
  features {}
}



locals {
  ressourceGroupName = "RateMyBeer${var.ressourceNameSuffix}"
  containerRegistryName = "RateMyBeerContainers${var.ressourceNameSuffix}"
  clusterName = "RateMyBeer${var.ressourceNameSuffix}"
  dnsLabel = "ratemybeer${var.ressourceNameSuffix}"
}

resource "azurerm_resource_group" "RateMyBeerRessourceGroup" {
  name     = local.ressourceGroupName
  location = var.location
}

resource "azurerm_container_registry" "RateMyBeerContainerRegistry" {
  name = local.containerRegistryName
  resource_group_name = azurerm_resource_group.RateMyBeerRessourceGroup.name
  location = azurerm_resource_group.RateMyBeerRessourceGroup.location
  sku = "Basic"
  admin_enabled = false
}

resource "azurerm_kubernetes_cluster" "RateMyBeerCluster" {
  name = local.clusterName
  resource_group_name = azurerm_resource_group.RateMyBeerRessourceGroup.name
  location = azurerm_resource_group.RateMyBeerRessourceGroup.location
  
  dns_prefix = local.dnsLabel
  default_node_pool {
    name = "default"
    node_count = var.clusterNodeCount
    vm_size    = var.clusterNodeVMSize
  }

  identity {
    type = "SystemAssigned"
  }
}

data "azurerm_resource_group" "RateMyBeerMCRessourceGroup" {
  name     = "MC_${local.ressourceGroupName}_${local.clusterName}_${azurerm_resource_group.RateMyBeerRessourceGroup.location}"
  depends_on = [
    azurerm_kubernetes_cluster.RateMyBeerCluster
  ]
}

resource "azurerm_public_ip" "RateMyBeerClusterIngressPublicIp" {
  name                = "KubernetesNginsIngressPublicIp"
  # create it in the mc ressource group means it will be deleted if the cluster is deleted!
  resource_group_name = data.azurerm_resource_group.RateMyBeerMCRessourceGroup.name
  location            = data.azurerm_resource_group.RateMyBeerMCRessourceGroup.location

  # create it in the cluster object ressource group means it will stay around if the cluster is deleted!
  # resource_group_name = azurerm_resource_group.RateMyBeerRessourceGroup.name
  # location            = azurerm_resource_group.RateMyBeerRessourceGroup.location

  sku = "Standard"
  allocation_method   = "Static"
  domain_name_label = "${local.dnsLabel}"
}

resource "azurerm_role_assignment" "acrpull_role" {
  scope                            = azurerm_container_registry.RateMyBeerContainerRegistry.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.RateMyBeerCluster.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

provider "helm" {
    kubernetes {
        host                   = azurerm_kubernetes_cluster.RateMyBeerCluster.kube_config.0.host
        client_key             = base64decode(azurerm_kubernetes_cluster.RateMyBeerCluster.kube_config.0.client_key)
        client_certificate     = base64decode(azurerm_kubernetes_cluster.RateMyBeerCluster.kube_config.0.client_certificate)
        cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.RateMyBeerCluster.kube_config.0.cluster_ca_certificate)
    }  
}

resource "helm_release" "nginx_ingress" {
  depends_on = [
    azurerm_public_ip.RateMyBeerClusterIngressPublicIp
  ]

  name       = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  repository  = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"

  # --set controller.replicaCount=3 ` 
  set {
    name  = "controller.replicaCount"
    value = var.clusterNodeCount
  }

  # --set controller.service.loadBalancerIP
  # Use pre-defined static ip instead of a dynamically generated one
  set {
    name  = "controller.servcie.loadBalancerIP"
    value = azurerm_public_ip.RateMyBeerClusterIngressPublicIp.ip_address
  }

  # --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-dns-label-name"=$DNS_LABEL `
  # set {
  #   name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-dns-label-name"
  #   value = local.dnsLabel
  # }

   # --set controller.nodeSelector."kubernetes\.io/os"=linux `
  set {
    name  = "controller.nodeSelector.kubernetes\\.io/os" 
    value = "linux"
  }
  
  # --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux `
  set {
    name  = "defaultBackend.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }

  # --set controller.admissionWebhooks.patch.nodeSelector."kubernetes\.io/os"=linux
  set {
    name = "controller.admissionWebhooks.patch.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  repository  = "https://charts.jetstack.io"
  chart      = "cert-manager"

  set {
    name  = "installCRDs"
    value = "true"
  }

}