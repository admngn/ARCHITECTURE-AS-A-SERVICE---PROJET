###############################################################################
# phase6-eks/terraform/main.tf
# Deploie : VPC dédié EKS + Cluster EKS + Node Group EC2
#
# IMPORTANT AWS Academy :
#   - Utilise LabRole existant (pas de création de rôles IAM)
#   - Node type : t3.medium minimum pour EKS
#   - Région : us-east-1
###############################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project   = "UniversiteExemple-POC"
      Phase     = "Phase6-EKS"
      ManagedBy = "Terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# ── IAM Roles existants AWS Academy ──────────────────────────────────────────
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# ── VPC dédié EKS ─────────────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc-eks"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = slice(data.aws_availability_zones.available.names, 0, 2)
}

# ── Cluster EKS ───────────────────────────────────────────────────────────────
module "eks" {
  source = "./modules/eks"

  project_name       = var.project_name
  environment        = var.environment
  aws_region         = var.aws_region
  cluster_version    = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  lab_role_arn       = data.aws_iam_role.lab_role.arn
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
  rds_endpoint       = var.rds_endpoint
  db_secret_name     = var.db_secret_name
}

###############################################################################
# Outputs
###############################################################################

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "kubeconfig_command" {
  description = "Commande pour configurer kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "next_steps" {
  value = <<-EOT
    ╔══════════════════════════════════════════════════════════════╗
    ║           PHASE 6 – EKS DÉPLOYÉ                            ║
    ╠══════════════════════════════════════════════════════════════╣
    ║  1. Configurer kubectl :                                    ║
    ║     aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}
    ║  2. Vérifier les nodes :                                   ║
    ║     kubectl get nodes                                       ║
    ║  3. Déployer l'app :                                       ║
    ║     kubectl apply -f k8s/base/                             ║
    ╚══════════════════════════════════════════════════════════════╝
  EOT
}
