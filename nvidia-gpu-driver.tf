resource "helm_release" "nvidia_gpu_driver" {
  count = var.nvidia_gpu_driver.enabled ? 1 : 0

  name       = "nvidia-device-plugin"
  repository = "https://la-cc.github.io/nvidia-device-plugin-helm-chart"
  chart      = "nvidia-device-plugin"
  namespace  = var.nvidia_gpu_driver.namespace

  create_namespace = var.nvidia_gpu_driver.create_namespace

  # Optional configs from the variable (merged into values)
  values = [
    jsonencode(var.nvidia_gpu_driver.configs)
  ]
}
