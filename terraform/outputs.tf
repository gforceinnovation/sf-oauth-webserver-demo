output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_url" {
  description = "URL to access the application"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_repository_url" {
  description = "ECR Repository URL"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "ECS Cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS Service name"
  value       = aws_ecs_service.app.name
}

output "secrets_manager_arn" {
  description = "ARN of Secrets Manager secret"
  value       = aws_secretsmanager_secret.sf_credentials.arn
}
