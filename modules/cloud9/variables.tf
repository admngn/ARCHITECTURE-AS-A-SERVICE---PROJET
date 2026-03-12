###############################################################################
# Module Cloud9 – Variables
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

variable "public_subnet_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "owner_arn" {
  type    = string
  default = ""
}

###############################################################################
# Module Cloud9 – Outputs
###############################################################################

output "environment_id" {
  description = "ID de l'environnement Cloud9"
  value       = aws_cloud9_environment_ec2.main.id
}

output "environment_name" {
  description = "Nom de l'environnement Cloud9"
  value       = aws_cloud9_environment_ec2.main.name
}

output "environment_arn" {
  description = "ARN de l'environnement Cloud9"
  value       = aws_cloud9_environment_ec2.main.arn
}
