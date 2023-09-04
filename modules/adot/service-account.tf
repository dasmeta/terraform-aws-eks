resource "aws_eks_addon" "this" {
  cluster_name = var.cluster_name
  addon_name   = "adot"
  # resolve_conflicts_on_update = "PRESERVE"
  addon_version            = "v0.78.0-eksbuild.1"
  service_account_role_arn = aws_iam_role.adot_collector.arn
  depends_on = [
    kubectl_manifest.this
  ]
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret" "example" {
  metadata {
    name      = "adot-collector"
    namespace = "adot"
  }
}

resource "kubernetes_service_account" "adot-collector" {
  metadata {
    name      = local.service_account_name
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.adot_collector.arn
    }
  }

  secret {
    name = kubernetes_secret.example.metadata.0.name
  }

}
