variable "ressourceNameSuffix" {
  description = "A suffix added to each ressource name. Can be set to empty string for production."
  type = string
  default = "4719"
}

variable "location" { 
  description = "Azure location where to put the ressources"
  type = string
  default = "westeurope"
}

variable "clusterNodeCount" { 
  description = "The number of nodes for the kubernetes Cluster."
  type = number
  default = 3
}

variable "clusterNodeVMSize" { 
  description = "The size SKU of the VM nodes of the cluster."
  type = string
  default = "Standard_B2s"
}