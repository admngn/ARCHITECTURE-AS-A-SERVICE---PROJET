###############################################################################
# Module Secrets – Variables
###############################################################################

variable "project_name" {
  type = string
}

variable "environment" {
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

variable "secret_recovery_days" {
  description = "Jours avant suppression définitive (0 = immédiate, min 7 en prod)"
  type        = number
  default     = 0
}

###############################################################################
# Module Secrets – Outputs
###############################################################################

output "secret_arn" {
  description = "ARN complet du secret Secrets Manager"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "secret_name" {
  description = "Nom du secret Secrets Manager"
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "secret_id" {
  description = "ID du secret Secrets Manager"
  value       = aws_secretsmanager_secret.db_credentials.id
}
