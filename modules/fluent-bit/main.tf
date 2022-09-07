/**
# Example Setup

```tf
module "fluent-bit" {
  source  = "dasmeta/eks/aws//modules/fluent-bit"
  version = "0.1.3"

  cluster_name                = "eks-cluster-name"
  oidc_provider_arn           = "eks_oidc_provider_arn"
  eks_oidc_root_ca_thumbprint = replace("eks_oidc_provider_arn", "/.*id//", "")
}
```
*/
