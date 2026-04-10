# Quickstart: Validate Karpenter System Isolation

## Prerequisites

- Terraform and AWS credentials configured for a test account.
- Access to an existing VPC/subnets suitable for EKS.
- `kubectl` configured to access the created cluster.

## 1) Initialize and apply example

Use `examples/eks-with-karpenter` as baseline:

1. Update environment-specific values in `0-setup.tf` and `1-example.tf`.
2. Run:
   - `terraform init`
   - `terraform plan`
   - `terraform apply`

## 2) Validate Karpenter replicas

- Check Karpenter deployment health:
  - `kubectl get pods -n karpenter`
- Confirm at least two controller pods are running.

## 3) Validate Karpenter priority class

- Inspect Karpenter pod priority class:
  - `kubectl get pod -n karpenter -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{.spec.priorityClassName}{"\n"}{end}'`
- Confirm all Karpenter pods use the highest predefined class.

## 4) Validate system-node isolation

- Deploy a non-critical test workload without explicit system-node tolerations.
- Run:
  - `kubectl get pods -A -o wide`
- Confirm test pods are not scheduled onto dedicated system nodes.

## 5) Failure-resilience check

- Delete one Karpenter controller pod:
  - `kubectl delete pod -n karpenter <pod-name>`
- Confirm another replica remains available and autoscaling control continues.

## Expected outcome

- Non-critical workloads do not run on system nodes by default.
- Karpenter runs with highest priority class.
- Karpenter maintains multi-replica availability baseline.
