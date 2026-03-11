output "public_ip" {
  description = "IP publique de l'instance — ouvre http://<public_ip> pour accéder à l'app"
  value       = aws_instance.app.public_ip
}

output "private_ip" {
  description = "Private IP of the app server"
  value       = aws_instance.app.private_ip
}

output "instance_id" {
  description = "Instance ID of the app server"
  value       = aws_instance.app.id
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = aws_subnet.private.id
}
