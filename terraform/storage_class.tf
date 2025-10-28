# ═══════════════════════════════════════════════════════════════
#  EBS CSI DRIVER (Instalación manual via Helm)
# ═══════════════════════════════════════════════════════════════
resource "helm_release" "ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  version    = "2.23.0"

  set {
    name  = "controller.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "ebs-csi-controller-sa"
  }

  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.ebs_csi_driver.arn
  }

  depends_on = [module.eks]
}

# ═══════════════════════════════════════════════════════════════
#  STORAGE CLASS CONFIGURATION
# ═══════════════════════════════════════════════════════════════
#
# Después de instalar el EBS CSI Driver, creamos un StorageClass
# moderno que use el nuevo driver.
#

resource "kubernetes_storage_class_v1" "ebs_gp3" {
  metadata {
    name = "gp3"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  
  parameters = {
    type   = "gp3"
    fsType = "ext4"
  }

  allow_volume_expansion = true

  depends_on = [module.eks]
}

# Opcional: Hacer gp3 el default
# resource "kubernetes_annotations" "gp3_default" {
#   api_version = "storage.k8s.io/v1"
#   kind        = "StorageClass"
#   force       = true
#   
#   metadata {
#     name = kubernetes_storage_class_v1.ebs_gp3.metadata[0].name
#   }
#   
#   annotations = {
#     "storageclass.kubernetes.io/is-default-class" = "true"
#   }
#   
#   depends_on = [kubernetes_storage_class_v1.ebs_gp3]
# }

