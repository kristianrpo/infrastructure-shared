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

# IAM Roles compartidos - Nombres compatibles con microservicios
output "aws_lb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = module.irsa_aws_load_balancer_controller.iam_role_arn
}

output "aws_load_balancer_controller_irsa_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller (alias)"
  value       = module.irsa_aws_load_balancer_controller.iam_role_arn
}

output "eso_irsa_role_arn" {
  description = "IAM role ARN for External Secrets Operator"
  value       = module.irsa_external_secrets.iam_role_arn
}

output "external_secrets_irsa_role_arn" {
  description = "IAM role ARN for External Secrets Operator (alias)"
  value       = module.irsa_external_secrets.iam_role_arn
}

output "eso_irsa_role_name" {
  description = "IAM role NAME for External Secrets Operator (for policy attachments)"
  value       = module.irsa_external_secrets.iam_role_name
}

# DynamoDB
output "rabbitmq_processed_messages_table_name" {
  description = "DynamoDB table name for RabbitMQ processed messages"
  value       = aws_dynamodb_table.rabbitmq_processed_messages.name
}

output "rabbitmq_processed_messages_table_arn" {
  description = "DynamoDB table ARN for RabbitMQ processed messages"
  value       = aws_dynamodb_table.rabbitmq_processed_messages.arn
}

# IAM Policy para consumidores RabbitMQ
output "rabbitmq_consumer_dynamodb_policy_arn" {
  description = "IAM policy ARN for RabbitMQ consumers to access DynamoDB"
  value       = aws_iam_policy.rabbitmq_consumer_dynamodb.arn
}

# ═══════════════════════════════════════════════════════════════
#  API GATEWAY
# ═══════════════════════════════════════════════════════════════
output "api_gateway_id" {
  description = "API Gateway HTTP API ID"
  value       = aws_apigatewayv2_api.microservices_api.id
}

output "api_gateway_arn" {
  description = "API Gateway HTTP API ARN"
  value       = aws_apigatewayv2_api.microservices_api.arn
}

output "api_gateway_endpoint" {
  description = "API Gateway HTTP API endpoint URL"
  value       = aws_apigatewayv2_api.microservices_api.api_endpoint
}

output "api_gateway_invoke_url" {
  description = "API Gateway invoke URL (for microservices to use)"
  value       = "${aws_apigatewayv2_api.microservices_api.api_endpoint}/${var.environment}"
}

output "api_gateway_vpc_link_id" {
  description = "VPC Link ID for connecting API Gateway to internal ALBs"
  value       = aws_apigatewayv2_vpc_link.microservices_vpc_link.id
}

output "api_gateway_execution_arn" {
  description = "API Gateway execution ARN (for IAM policies)"
  value       = aws_apigatewayv2_api.microservices_api.execution_arn
}

# ═══════════════════════════════════════════════════════════════
#  MONITOREO (Prometheus & Grafana)
# ═══════════════════════════════════════════════════════════════
output "prometheus_stack_namespace" {
  description = "Namespace donde está instalado el stack de Prometheus/Grafana"
  value       = "monitoring"
}

output "prometheus_service_name" {
  description = "Nombre del servicio de Prometheus"
  value       = "kube-prometheus-stack-prometheus"
}

output "grafana_service_name" {
  description = "Nombre del servicio de Grafana"
  value       = "kube-prometheus-stack-grafana"
}