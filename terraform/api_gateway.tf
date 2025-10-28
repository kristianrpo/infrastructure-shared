# ═══════════════════════════════════════════════════════════════
#  API GATEWAY PARA MICROSERVICIOS
# ═══════════════════════════════════════════════════════════════
# 
# Este API Gateway actúa como punto de entrada único para todos
# los microservicios. Se conecta a los ALB de cada microservicio
# a través de un VPC Link privado.
#
# Arquitectura:
#   Internet → API Gateway → VPC Link → ALB (K8s) → Pods
#

# ═══════════════════════════════════════════════════════════════
#  VPC LINK (Conexión privada del API Gateway a la VPC)
# ═══════════════════════════════════════════════════════════════
resource "aws_apigatewayv2_vpc_link" "microservices_vpc_link" {
  name               = "${local.name}-vpc-link"
  security_group_ids = [module.eks.node_security_group_id]
  subnet_ids         = module.vpc.private_subnets

  tags = {
    Name = "${local.name}-vpc-link"
  }

  depends_on = [module.eks]
}

# ═══════════════════════════════════════════════════════════════
#  API GATEWAY HTTP API (más moderno y barato que REST API)
# ═══════════════════════════════════════════════════════════════
resource "aws_apigatewayv2_api" "microservices_api" {
  name          = "${local.name}-api-gateway"
  protocol_type = "HTTP"
  description   = "API Gateway for microservices in ${var.environment}"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"]
    allow_headers = ["*"]
    max_age       = 300
  }

  tags = {
    Name = "${local.name}-api-gateway"
  }
}

# ═══════════════════════════════════════════════════════════════
#  STAGE de la API
# ═══════════════════════════════════════════════════════════════
resource "aws_apigatewayv2_stage" "api_stage" {
  api_id      = aws_apigatewayv2_api.microservices_api.id
  name        = var.environment
  auto_deploy = true

  default_route_settings {
    detailed_metrics_enabled = true
    throttling_burst_limit   = 500
    throttling_rate_limit    = 1000
  }

  tags = {
    Name = "${local.name}-api-${var.environment}"
  }
}

# ═══════════════════════════════════════════════════════════════
#  IAM ROLE para API Gateway (permite integración con servicios privados)
# ═══════════════════════════════════════════════════════════════
resource "aws_iam_role" "api_gateway_integration" {
  name = "${local.name}-api-gateway-integration"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${local.name}-api-gateway-integration-role"
  }
}

resource "aws_iam_role_policy" "api_gateway_integration_policy" {
  name = "${local.name}-api-gateway-integration-policy"
  role = aws_iam_role.api_gateway_integration.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}
