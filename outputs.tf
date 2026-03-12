###############################################################################
# Outputs – Phase 2
###############################################################################

# ── Réseau ───────────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "ID du VPC principal"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs des sous-réseaux publics (EC2 webapp)"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs des sous-réseaux privés (RDS)"
  value       = module.vpc.private_subnet_ids
}

# ── EC2 Application ──────────────────────────────────────────────────────────

output "app_instance_id" {
  description = "ID de l'instance EC2 applicative"
  value       = module.ec2.instance_id
}

output "app_public_ip" {
  description = "Adresse IP publique de l'instance EC2"
  value       = module.ec2.public_ip
}

output "app_public_dns" {
  description = "DNS public de l'instance EC2"
  value       = module.ec2.public_dns
}

output "app_url" {
  description = "URL d'accès à l'application web"
  value       = "http://${module.ec2.public_ip}"
}

output "ssh_command" {
  description = "Commande SSH pour se connecter à l'instance EC2"
  value       = "ssh -i ${var.key_pair_name}.pem ubuntu@${module.ec2.public_ip}"
}

# ── RDS ──────────────────────────────────────────────────────────────────────

output "rds_endpoint" {
  description = "Endpoint de connexion RDS (sans le port)"
  value       = module.rds.db_endpoint
}

output "rds_port" {
  description = "Port de la base de données RDS"
  value       = module.rds.db_port
}

output "rds_database_name" {
  description = "Nom de la base de données"
  value       = var.db_name
}

# ── Secrets Manager ──────────────────────────────────────────────────────────

output "secret_arn" {
  description = "ARN du secret Secrets Manager (identifiants DB)"
  value       = module.secrets.secret_arn
}

output "secret_name" {
  description = "Nom du secret dans Secrets Manager"
  value       = module.secrets.secret_name
}

# ── Cloud9 ───────────────────────────────────────────────────────────────────

output "cloud9_environment_id" {
  description = "ID de l'environnement Cloud9"
  value       = module.cloud9.environment_id
}

output "cloud9_environment_url" {
  description = "URL d'accès à l'environnement Cloud9"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloud9/ide/${module.cloud9.environment_id}"
}

# ── Récapitulatif ─────────────────────────────────────────────────────────────

output "deployment_summary" {
  description = "Récapitulatif du déploiement Phase 2"
  value = {
    application_url    = "http://${module.ec2.public_ip}"
    rds_endpoint       = module.rds.db_endpoint
    secret_name        = module.secrets.secret_name
    cloud9_url         = "https://${var.aws_region}.console.aws.amazon.com/cloud9/ide/${module.cloud9.environment_id}"
    migration_command  = "Utilisez le Script-3 dans Cloud9 pour migrer les données"
  }
}

output "next_steps" {
  description = "Prochaines étapes après le déploiement"
  value = <<-EOT
    ╔══════════════════════════════════════════════════════════════╗
    ║           PHASE 2 – DÉPLOIEMENT TERMINÉ                    ║
    ╠══════════════════════════════════════════════════════════════╣
    ║  1. Application : http://${module.ec2.public_ip}
    ║  2. Cloud9 : Ouvrez l'IDE via la Console AWS
    ║  3. Migration : Exécutez Script-3 dans Cloud9
    ║  4. Test CRUD : Vérifiez l'application web
    ╚══════════════════════════════════════════════════════════════╝
  EOT
}
