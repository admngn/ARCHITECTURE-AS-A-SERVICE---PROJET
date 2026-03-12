###############################################################################
# Module VPC – Outputs
###############################################################################

output "vpc_id" {
  description = "ID du VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "Bloc CIDR du VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs des sous-réseaux publics"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs des sous-réseaux privés"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID de l'Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "ID du NAT Gateway"
  value       = aws_nat_gateway.main.id
}

output "public_route_table_id" {
  description = "ID de la Route Table publique"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID de la Route Table privée"
  value       = aws_route_table.private.id
}
