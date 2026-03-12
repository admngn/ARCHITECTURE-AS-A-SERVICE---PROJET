###############################################################################
# Module EC2 – Variables
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

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "key_pair_name" {
  type = string
}

variable "db_host" {
  type    = string
  default = ""
}

variable "db_name" {
  type = string
}

variable "db_port" {
  type = number
}

variable "secret_arn" {
  type = string
}

variable "app_port" {
  type = number
}

variable "userdata_script_url" {
  type = string
}

###############################################################################
# Module EC2 – Outputs
###############################################################################

output "instance_id" {
  description = "ID de l'instance EC2"
  value       = aws_instance.app.id
}

output "public_ip" {
  description = "Adresse IP publique (Elastic IP)"
  value       = aws_eip.app.public_ip
}

output "private_ip" {
  description = "Adresse IP privée de l'instance"
  value       = aws_instance.app.private_ip
}

output "public_dns" {
  description = "DNS public de l'Elastic IP"
  value       = aws_eip.app.public_dns
}

output "app_security_group_id" {
  description = "ID du Security Group de l'application EC2"
  value       = aws_security_group.app.id
}

output "iam_role_arn" {
  description = "ARN du LabRole utilise par l'instance EC2"
  value       = data.aws_iam_role.lab_role.arn
}
