#locals {
#  roles = [
#    {
#      name      = "role1"
#      actions   = ["get", "list", "watch"]
#      resources = ["deployments"]
#    },
#    {
#      name      = "role2"
#      actions   = ["get", "list", "watch"]
#      resources = ["pods"]
#    }
#  ]
#
#
#  bindings = [
#    {
#      group     = "development"
#      namespace = "development"
#      roles     = ["role1", "role2"]
#    },
#    {
#      group     = "accounting"
#      namespace = "accounting"
#      roles     = ["role1"]
#    }
#  ]
#}
#
#module "eks" {
#  source = "complete-cluster"
#
#  roles    = local.roles
#  bindings = local.bindings
#}
