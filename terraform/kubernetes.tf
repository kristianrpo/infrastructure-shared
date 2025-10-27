# ═══════════════════════════════════════════════════════════════
#  AWS LOAD BALANCER CONTROLLER (Instalar primero)
# ═══════════════════════════════════════════════════════════════
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.6.2"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.irsa_aws_load_balancer_controller.iam_role_arn
  }

  # Esperar a que el deployment esté listo antes de continuar
  wait          = true
  wait_for_jobs = true
  timeout       = 900

  depends_on = [
    module.irsa_aws_load_balancer_controller,
    module.eks
  ]
}

# Esperar a que el webhook del ALB Controller esté completamente operativo
resource "time_sleep" "wait_for_alb_controller" {
  depends_on      = [helm_release.aws_load_balancer_controller]
  create_duration = "30s"
}

# ═══════════════════════════════════════════════════════════════
#  EXTERNAL SECRETS OPERATOR (Instalar después)
# ═══════════════════════════════════════════════════════════════
resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = "external-secrets"
  }

  depends_on = [time_sleep.wait_for_alb_controller]
}

resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = kubernetes_namespace.external_secrets.metadata[0].name
  version    = "0.9.11"

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.irsa_external_secrets.iam_role_arn
  }

  # Esperar a que el deployment esté listo antes de continuar
  # Increased timeout to 15 minutes for slow EKS deployments
  wait          = true
  wait_for_jobs = true
  timeout       = 900

  depends_on = [
    module.irsa_external_secrets,
    module.eks,
    time_sleep.wait_for_alb_controller
  ]
}