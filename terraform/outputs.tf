# VPC
output "vpc_id" {
  description = "VPC ID compartida"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

# EKS
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "EKS cluster CA certificate"
  value       = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "node_security_group_id" {
  description = "Security group ID of EKS nodes"
  value       = module.eks.node_security_group_id
}

# RabbitMQ
output "rabbitmq_amqp_url" {
  description = "RabbitMQ connection URL"
  value       = "amqps://appuser:${random_password.rabbitmq_password.result}@${replace(replace(aws_mq_broker.rabbitmq.instances[0].endpoints[0], "amqps://", ""), "amqp://", "")}/"
  sensitive   = true
}

output "rabbitmq_broker_id" {
  description = "RabbitMQ broker ID"
  value       = aws_mq_broker.rabbitmq.id
}

output "rabbitmq_host" {
  description = "RabbitMQ host (sin protocolo ni credenciales)"
  value       = replace(replace(aws_mq_broker.rabbitmq.instances[0].endpoints[0], "amqps://", ""), "amqp://", "")
}

# IAM Roles compartidos
output "aws_lb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = module.irsa_aws_load_balancer_controller.iam_role_arn
}

output "eso_irsa_role_arn" {
  description = "IAM role ARN for External Secrets Operator"
  value       = module.irsa_external_secrets.iam_role_arn
}

output "eso_irsa_role_name" {
  description = "IAM role NAME for External Secrets Operator (for policy attachments)"
  value       = module.irsa_external_secrets.iam_role_name
}