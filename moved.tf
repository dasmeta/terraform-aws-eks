# State migration: Move helm_release.cert-manager to module.cert-manager.helm_release.cert-manager
# Terraform will automatically handle the migration if the old resource exists in state
moved {
  from = helm_release.cert-manager[0]
  to   = module.cert-manager[0].helm_release.cert-manager
}
