resource "null_resource" "kubectl-version" {
  provisioner "local-exec" {
    command     = "kubectl version | base64 | tr -d '\n' > ./.terraform/kversion"
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "null_resource" "kubectl-apply" {
  depends_on = [null_resource.kubectl-version]
  provisioner "local-exec" {
    command     = "kubectl apply -f 'https://cloud.weave.works/k8s/scope.yaml?k8s-version=${file("./.terraform/kversion")}'"
    interpreter = ["/bin/bash", "-c"]
  }
}
