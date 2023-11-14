resource "kubernetes_service_account" "servciceaccount" {
  metadata {
    name      = "ack-apigatewayv2-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.role.arn
    }
  }
}
