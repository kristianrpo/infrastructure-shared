# Infrastructure Shared

Repositorio de infraestructura compartida para todos los microservicios.

## 🏗️ Recursos Compartidos

Este repositorio provisiona:
- ✅ VPC con subredes públicas y privadas
- ✅ EKS Cluster (Kubernetes)
- ✅ RabbitMQ (broker compartido)
- ✅ IAM Roles compartidos (ALB Controller, External Secrets Operator)
- ✅ API Gateway (punto de entrada para microservicios)
- ✅ Prometheus + Grafana (monitoreo centralizado)

## 📦 Terraform State

El state se almacena en:
- **S3 Bucket**: `${TF_BACKEND_BUCKET}`
- **Key**: `shared/terraform.tfstate`
- **DynamoDB Table**: `${TF_BACKEND_DDB_TABLE}` (para locks)

## 🚀 Deployment

### Automático (GitHub Actions)
Push a `main` para desplegar automáticamente.

### Manual
```bash
cd terraform

# Inicializar
terraform init \
  -backend-config="bucket=${TF_BACKEND_BUCKET}" \
  -backend-config="key=shared/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="dynamodb_table=${TF_BACKEND_DDB_TABLE}"

# Planificar
terraform plan

# Aplicar
terraform apply
```

## 📤 Outputs

Los servicios consumen estos outputs vía `terraform_remote_state`:
```hcl
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = var.tf_backend_bucket
    key    = "shared/terraform.tfstate"
    region = var.aws_region
  }
}

# Usar:
# data.terraform_remote_state.shared.outputs.cluster_name
# data.terraform_remote_state.shared.outputs.rabbitmq_amqp_url
# data.terraform_remote_state.shared.outputs.api_gateway_invoke_url
# etc.
```

Principales outputs disponibles:
- `cluster_name` - Nombre del cluster EKS
- `rabbitmq_amqp_url` - URL de conexión a RabbitMQ (sensitive)
- `api_gateway_invoke_url` - URL del API Gateway
- `prometheus_stack_namespace` - Namespace de monitoreo
- Ver `terraform/outputs.tf` para la lista completa

## 🗑️ Destrucción

**⚠️ ADVERTENCIA**: Esto destruirá TODA la infraestructura compartida y afectará a TODOS los servicios.

En GitHub Actions → Actions → Destroy Shared Infrastructure → Run workflow

O manualmente:
```bash
cd terraform
terraform destroy
```

## 📋 Variables

| Variable | Default | Descripción |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | AWS region |
| `project` | `mycompany` | Nombre del proyecto |
| `environment` | `dev` | Ambiente (dev/staging/prod) |
| `vpc_cidr` | `10.42.0.0/16` | CIDR de la VPC |
| `eks_version` | `1.30` | Versión de Kubernetes |
| `eks_node_min_size` | `2` | Mínimo de nodos EKS |
| `eks_node_max_size` | `6` | Máximo de nodos EKS |

## 🔒 Secrets de GitHub

Configurar en Settings → Secrets and variables → Actions:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `TF_BACKEND_BUCKET`
- `TF_BACKEND_DDB_TABLE`

## 📊 Monitoreo

### Acceso a Grafana

El stack de monitoreo (Prometheus + Grafana) está desplegado en el namespace `monitoring`.

**Acceso local via port-forward:**
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Abre http://localhost:3000
# Usuario: admin / Contraseña: admin
```

**Acceso público (si el Ingress está habilitado):**
```bash
# Obtener URL del ALB
kubectl get ingress -n monitoring grafana-ingress
```

### Configurar Microservicios para Monitoreo

Ver [docs/MONITORING_SETUP.md](docs/MONITORING_SETUP.md) para instrucciones detalladas.

Resumen:
1. Crear `ServiceMonitor` en cada microservicio
2. Crear ConfigMap con dashboard de Grafana
3. Exponer métricas en `/metrics`