module "weave-scope-with-ingress" {
  source        = "./modules/weave-scope"
  ingress_class = "nginx"
  ingress_host  = "www.weave-scope.com"
  ingress_name  = "weave-ingress"
}
