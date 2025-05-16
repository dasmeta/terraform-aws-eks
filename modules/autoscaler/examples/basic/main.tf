locals {
  cluster_name = "dev"
}

module "cluster_min" {
  source = "../.."

  cluster_name             = local.cluster_name
  cluster_oidc_arn         = ""
  autoscaler_image_patch   = 0 #(Optional)
  scale_down_unneeded_time = 2 #(Scale down unneeded time in minutes, default is 2 minutes)
}
