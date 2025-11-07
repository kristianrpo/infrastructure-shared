locals {
  name = "${var.project}-${var.environment}"

  azs = [
    "${var.aws_region}a",
    "${var.aws_region}b"
  ]

  private_subnets = [
    cidrsubnet(var.vpc_cidr, 8, 1),
    cidrsubnet(var.vpc_cidr, 8, 2)
  ]

  public_subnets = [
    cidrsubnet(var.vpc_cidr, 8, 101),
    cidrsubnet(var.vpc_cidr, 8, 102)
  ]
}

resource "random_id" "suffix" {
  byte_length = 2
}

# ═══════════════════════════════════════════════════════════════
#  VPC COMPARTIDA
# ═══════════════════════════════════════════════════════════════
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags para EKS
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = {
    Name = "${local.name}-vpc"
  }
}

# ═══════════════════════════════════════════════════════════════
#  EKS CLUSTER COMPARTIDO
# ═══════════════════════════════════════════════════════════════
data "aws_caller_identity" "current" {}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name    = local.name
  cluster_version = var.eks_version

  cluster_endpoint_public_access = true
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa                 = true
  create_cloudwatch_log_group = false

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    # Nota: ebs-csi-driver no está disponible como addon para EKS 1.30
    # Lo instalamos manualmente via Helm en storage_class.tf
    # ebs-csi-driver = {
    #   most_recent = true
    # }
  }

  eks_managed_node_groups = {
    default = {
      name = "${local.name}-node-group"
      
      min_size     = var.eks_node_min_size
      max_size     = var.eks_node_max_size
      desired_size = var.eks_node_desired_size

      instance_types = var.eks_node_instance_types
      capacity_type  = "ON_DEMAND"

      labels = {
        Environment = var.environment
        NodeGroup   = "default"
      }

      tags = {
        Name = "${local.name}-eks-node"
      }
    }
  }

  # Acceso admin para el pipeline
  access_entries = {
    pipeline_admin = {
      principal_arn = data.aws_caller_identity.current.arn
      policy_associations = [{
        policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = { type = "cluster" }
      }]
    }
  }

  tags = {
    Name = "${local.name}-eks"
  }
}

# ═══════════════════════════════════════════════════════════════
#  RABBITMQ COMPARTIDO
# ═══════════════════════════════════════════════════════════════
resource "random_password" "rabbitmq_password" {
  length           = 20
  special          = true
  override_special = "!@#$%^&*()-_+."
}

resource "aws_security_group" "rabbitmq" {
  name_prefix = "${local.name}-rabbitmq-sg-"
  description = "Security group for shared RabbitMQ broker"
  vpc_id      = module.vpc.vpc_id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-rabbitmq-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "rabbitmq_from_eks_nodes" {
  type                     = "ingress"
  from_port                = 5671
  to_port                  = 5671
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rabbitmq.id
  source_security_group_id = module.eks.node_security_group_id
  description              = "Allow AMQPS from EKS nodes"
}

resource "aws_mq_broker" "rabbitmq" {
  broker_name                = "${local.name}-rabbitmq-${random_id.suffix.hex}"
  engine_type                = "RabbitMQ"
  engine_version             = "3.13"
  auto_minor_version_upgrade = true
  host_instance_type         = var.rabbitmq_instance_type
  publicly_accessible        = false
  deployment_mode            = "CLUSTER"

  user {
    username = "appuser"
    password = random_password.rabbitmq_password.result
  }

  subnet_ids      = [module.vpc.private_subnets[0]]
  security_groups = [aws_security_group.rabbitmq.id]

  logs {
    general = true
  }

  tags = {
    Name = "${local.name}-rabbitmq"
  }

  depends_on = [
    aws_security_group.rabbitmq,
    aws_security_group_rule.rabbitmq_from_eks_nodes,
    module.eks  # Asegurar que EKS existe antes de crear RabbitMQ
  ]
}

# ═══════════════════════════════════════════════════════════════
#  DYNAMODB: TABLA DE MENSAJES PROCESADOS (Idempotencia RabbitMQ)
# ═══════════════════════════════════════════════════════════════
# 
# Esta tabla almacena los mensajes de RabbitMQ que ya fueron procesados
# para evitar que se procesen duplicados (idempotencia).
#
# IMPORTANTE: Esta tabla se crea automáticamente en la infraestructura
# compartida. El código Go del consumidor NO debe ejecutar EnsureTableExists()
# ya que la tabla ya existe. Solo debe verificar/insertar registros.
#
# Estructura (coincide con el código Go del consumidor):
# - MessageID (PK): ID único del mensaje (tipo String)
# - processed_at: Timestamp de cuándo se procesó
# - ttl: Tiempo de expiración para limpieza automática
#
# Para usar esta tabla en tu microservicio consumidor:
# 1. Crea un IRSA role en tu terraform del microservicio
# 2. Asocia la policy: rabbitmq_consumer_dynamodb_policy_arn
# 3. Usa los outputs para obtener el nombre de la tabla
# 4. Configura el nombre de la tabla como variable de entorno

resource "aws_dynamodb_table" "rabbitmq_processed_messages" {
  name         = "${local.name}-rabbitmq-processed-messages"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "MessageID"

  attribute {
    name = "MessageID"
    type = "S"
  }

  # TTL para limpiar mensajes antiguos automáticamente (14 días)
  ttl {
    enabled        = true
    attribute_name  = "ttl"
  }

  # Point-in-time recovery para prevenir pérdida de datos
  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name        = "${local.name}-rabbitmq-processed-messages"
    Environment = var.environment
    Purpose     = "RabbitMQ message idempotency tracking"
  }
}


resource "aws_iam_policy" "rabbitmq_consumer_dynamodb" {
  name_prefix = "${local.name}-rabbitmq-consumer-dynamodb-"
  description = "IAM policy for RabbitMQ consumers to access DynamoDB for idempotency"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.rabbitmq_processed_messages.arn
        ]
      }
    ]
  })

  tags = {
    Name = "${local.name}-rabbitmq-consumer-dynamodb-policy"
  }
}