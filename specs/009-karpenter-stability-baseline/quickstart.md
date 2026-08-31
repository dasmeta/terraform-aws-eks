# Quickstart: Karpenter Stability Baseline

**Feature**: `specs/009-karpenter-stability-baseline`

## Prerequisites

Terraform 1.6+ for native tests (local is 1.13.0). AWS credentials are needed only for the example-based checks, not for the test assertions.

## Run the native tests

```sh
# from repository root
terraform init -backend=false
terraform test
```

These assert plan-time behaviour that needs no cloud access: image selection determinism, rendered disruption budgets, controller resource shape, and the replica/subnet precondition.

## Verify image selection determinism (SC-003)

The defect being fixed is that this could change between runs without any configuration change:

```sh
cd examples/eks-with-karpenter
terraform plan -out=/tmp/p1.tfplan && terraform show -json /tmp/p1.tfplan \
  | jq -r '.. | .amiSelectorTerms? // empty'
```

Run twice with node turnover in between. Before this feature the selected image could differ; after it, the two outputs must be identical.

## Inspect the rendered node pools

```sh
terraform plan -out=/tmp/p.tfplan
terraform show -json /tmp/p.tfplan | jq -r '.. | select(.chart? == "karpenter-nodes") | .values'
```

Confirm every pool carries a `disruption.budgets` entry with `schedule`, `duration`, and `reasons`, and that `terminationGracePeriod` is present.

## Confirm the controller has no CPU limit

```sh
kubectl -n karpenter get deploy karpenter -o jsonpath='{.spec.template.spec.containers[0].resources}' | jq
```

Expect `requests.cpu: 250m`, `requests.memory: 512Mi`, `limits.memory: 1Gi`, and **no** `limits.cpu`. A CPU limit here is the defect, not the fix.

## Confirm controller priority

```sh
kubectl -n karpenter get pod -l app.kubernetes.io/name=karpenter \
  -o jsonpath='{.items[*].spec.priorityClassName}'
```

Expect `system-cluster-critical`.

## Diagnose a Pending second replica

The module fails the plan when replicas exceed 1 with fewer than 2 subnets, but it cannot see node count or zone spread. If a replica is still Pending:

```sh
kubectl -n karpenter describe pod -l app.kubernetes.io/name=karpenter | grep -A5 Events
kubectl get nodes -L topology.kubernetes.io/zone
```

Two replicas need two non-Karpenter nodes in two different availability zones.

## Examples

```sh
cd examples/eks-with-karpenter                      # new defaults
cd examples/eks-with-karpenter-and-external-secret  # protected node pool enabled
terraform init && terraform plan
```
