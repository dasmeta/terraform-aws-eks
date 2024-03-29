resource "kubernetes_service_account" "servciceaccount" {
  metadata {
    name      = "efs-csi-controller-sa"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name" = "aws-efs-csi-driver"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.role.arn
    }
  }
}
