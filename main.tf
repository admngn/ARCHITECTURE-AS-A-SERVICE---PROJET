###############################################################################
# Université Exemple – POC AWS
# Phase 2 : Découplage des composants (VPC étendu, RDS, EC2 App, Secrets Manager, Cloud9)
# Terraform >= 1.5
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # ── Décommentez pour stocker le state à distance (recommandé en équipe) ──
  # backend "s3" {
  #   bucket         = "mon-bucket-tfstate"
  #   key            = "universite-exemple/phase2/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "UniversiteExemple-POC"
      Phase       = "Phase2-Decouplage"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

###############################################################################
# Données dynamiques
###############################################################################

data "aws_availability_zones" "available" {
  state = "available"
}

# AMI Ubuntu 22.04 LTS – utilisée par le module EC2
data "aws_ami" "ubuntu_22" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

###############################################################################
# Modules
###############################################################################

module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "secrets" {
  source = "./modules/secrets"

  project_name    = var.project_name
  environment     = var.environment
  db_name         = var.db_name
  db_username     = var.db_username
  db_password     = random_password.db_password.result
  db_port         = var.db_port
}

module "rds" {
  source = "./modules/rds"

  project_name         = var.project_name
  environment          = var.environment
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  app_security_group_id = module.ec2.app_security_group_id

  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = random_password.db_password.result
  db_instance_class    = var.db_instance_class
  db_engine_version    = var.db_engine_version
  db_allocated_storage = var.db_allocated_storage
  db_port              = var.db_port
  multi_az             = var.db_multi_az
  deletion_protection  = var.db_deletion_protection
}

module "ec2" {
  source = "./modules/ec2"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  public_subnet_id   = module.vpc.public_subnet_ids[0]
  ami_id             = data.aws_ami.ubuntu_22.id
  instance_type      = var.ec2_instance_type
  key_pair_name      = var.key_pair_name

  db_host            = module.rds.db_endpoint
  db_name            = var.db_name
  db_port            = var.db_port
  secret_arn         = module.secrets.secret_arn

  app_port           = var.app_port
  userdata_script_url = var.userdata_script_url
}

module "cloud9" {
  source = "./modules/cloud9"

  project_name     = var.project_name
  environment      = var.environment
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet_ids[0]
  instance_type    = var.cloud9_instance_type
  owner_arn        = var.cloud9_owner_arn
}

###############################################################################
# Mot de passe aléatoire pour RDS (géré via Secrets Manager)
###############################################################################

resource "random_password" "db_password" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}:?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}
