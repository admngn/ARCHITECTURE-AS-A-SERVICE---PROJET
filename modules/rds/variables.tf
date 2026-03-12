###############################################################################
# Module RDS – Variables
###############################################################################

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "app_security_group_id" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_port" {
  type = number
}

variable "db_instance_class" {
  type = string
}

variable "db_engine_version" {
  type = string
}

variable "db_allocated_storage" {
  type = number
}

variable "multi_az" {
  type = bool
}

variable "deletion_protection" {
  type = bool
}

###############################################################################
# Module RDS – Outputs
###############################################################################

output "db_instance_id" {
  description = "ID de l'instance RDS"
  value       = aws_db_instance.main.id
}

output "db_endpoint" {
  description = "Endpoint de connexion RDS (hostname uniquement, sans port)"
  value       = aws_db_instance.main.address
}

output "db_endpoint_full" {
  description = "Endpoint complet avec port"
  value       = aws_db_instance.main.endpoint
}

output "db_port" {
  description = "Port de la base de données"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Nom de la base de données"
  value       = aws_db_instance.main.db_name
}

output "db_arn" {
  description = "ARN de l'instance RDS"
  value       = aws_db_instance.main.arn
}

output "rds_security_group_id" {
  description = "ID du Security Group RDS"
  value       = aws_security_group.rds.id
}
