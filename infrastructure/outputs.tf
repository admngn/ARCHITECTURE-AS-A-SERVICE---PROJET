output "alb_dns_name" {
  description = "L'URL de ton Load Balancer pour acceder a l'application"
  value       = aws_lb.app_alb.dns_name
}