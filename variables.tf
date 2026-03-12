###############################################################################
# Variables – Phase 2 : Découplage des composants
###############################################################################

# ── Général ──────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "Région AWS pour le déploiement"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nom du projet (utilisé comme préfixe sur toutes les ressources)"
  type        = string
  default     = "universite-exemple"
}

variable "environment" {
  description = "Environnement de déploiement (poc, dev, staging, prod)"
  type        = string
  default     = "poc"

  validation {
    condition     = contains(["poc", "dev", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être : poc, dev, staging ou prod."
  }
}

# ── Réseau ───────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "Bloc CIDR du VPC principal"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Blocs CIDR des sous-réseaux publics (un par AZ – pour EC2 webapp)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Blocs CIDR des sous-réseaux privés (un par AZ – pour RDS)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

# ── EC2 Application ──────────────────────────────────────────────────────────

variable "ec2_instance_type" {
  description = "Type d'instance EC2 pour le serveur applicatif"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "Nom de la paire de clés SSH EC2 (doit exister dans la région)"
  type        = string
  # Pas de default – doit être fourni par l'utilisateur
}

variable "app_port" {
  description = "Port d'écoute de l'application Node.js"
  type        = number
  default     = 80
}

variable "userdata_script_url" {
  description = "URL du script UserData pour l'instance EC2 applicative"
  type        = string
  default     = "https://aws-tc-largeobjects.s3.us-west-2.amazonaws.com/CUR-TF-200-ACCAP1-1-91571/1-lab-capstone-project-1/s3/UserdataScript-phase-2.sh"
}

# ── RDS ──────────────────────────────────────────────────────────────────────

variable "db_name" {
  description = "Nom de la base de données MySQL"
  type        = string
  default     = "students"
}

variable "db_username" {
  description = "Nom d'utilisateur principal de la base de données"
  type        = string
  default     = "dbadmin"
}

variable "db_port" {
  description = "Port de la base de données MySQL/MariaDB"
  type        = number
  default     = 3306
}

variable "db_instance_class" {
  description = "Classe d'instance RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine_version" {
  description = "Version du moteur MySQL RDS"
  type        = string
  default     = "8.0"
}

variable "db_allocated_storage" {
  description = "Espace disque alloué à RDS en Go"
  type        = number
  default     = 20
}

variable "db_multi_az" {
  description = "Activer le déploiement Multi-AZ pour RDS (Phase 2 : false pour économiser)"
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Activer la protection contre la suppression accidentelle de RDS"
  type        = bool
  default     = false
}

# ── Secrets Manager ──────────────────────────────────────────────────────────

variable "secret_recovery_days" {
  description = "Jours de rétention avant suppression définitive du secret (0 = immédiate)"
  type        = number
  default     = 0
}

# ── Cloud9 ───────────────────────────────────────────────────────────────────

variable "cloud9_instance_type" {
  description = "Type d'instance EC2 pour l'environnement Cloud9"
  type        = string
  default     = "t3.small"
}

variable "cloud9_owner_arn" {
  description = "ARN du propriétaire de l'environnement Cloud9 (ARN utilisateur IAM)"
  type        = string
  default     = ""  # Si vide, utilise l'identité courante
}
