module "weave-scope-with-ingress" {
  source = "../"

  ingress_enabled = true
  ingress_host    = "some.domain.name"
}
