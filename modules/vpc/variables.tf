###############################################################################
# Module VPC – Variables
###############################################################################

variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "environment" {
  description = "Environnement de déploiement"
  type        = string
}

variable "vpc_cidr" {
  description = "Bloc CIDR du VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Blocs CIDR des sous-réseaux publics"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Blocs CIDR des sous-réseaux privés"
  type        = list(string)
}

variable "availability_zones" {
  description = "Zones de disponibilité à utiliser"
  type        = list(string)
}
