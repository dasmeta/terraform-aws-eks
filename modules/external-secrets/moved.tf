# State moves for consumers upgrading across the external-secrets rewrite.
#
# Up to v2.27.0 the chart was installed through the `terraform-module/release/helm` wrapper,
# which held the release at `module.release.helm_release.this[0]`. It is now a plain
# helm_release. Without this block Terraform reads the old address as "no longer in
# configuration" and plans to destroy the release and create it again - uninstalling
# external-secrets and leaving every ExternalSecret unreconciled while it is gone. The `moved`
# block re-points the existing state entry at the new address instead, so upgrading is an
# in-place `helm upgrade` and the release is never uninstalled.
#
# Keep this block: removing it re-breaks the upgrade path for anyone still on <= v2.27.0.
moved {
  from = module.release.helm_release.this[0]
  to   = helm_release.this
}
