#!/usr/bin/env bash
#
# Prepare an EKS cluster for `terraform destroy`. THIS MUTATES THE CLUSTER -- it deletes the kubernetes
# objects that own AWS resources, then waits for those AWS resources to actually be gone.
#
# WHY THIS EXISTS. Terraform owns what it created: the VPC, the subnets, the security groups, the cluster.
# It does not own what controllers inside the cluster created on its behalf -- load balancers and their
# ENIs from the load balancer controller, EC2 instances from karpenter. There is no edge in the graph to
# any of them, so terraform cannot order against them and destroys the controllers while they are still
# cleaning up. The orphaned ENIs then hold the node security group, and the run fails fifteen minutes later
# on `DependencyViolation: resource sg-... has a dependent object` -- a security group that is not the
# problem, named because it is the first thing that could not be deleted.
#
# The module holds those controllers alive briefly on destroy, which helps when terraform owns the Ingress
# objects. It cannot help when something else created them, and it cannot know whether AWS finished
# releasing the ENIs, because a fixed wait is a guess. This script waits for the actual state instead.
#
# ZERO CONFIGURATION. Cluster and region come from the current kube context:
#
#   ./scripts/eks-destroy-prep.sh               # delete, wait, then check
#   ./scripts/eks-destroy-prep.sh --dry-run     # show what would be deleted, change nothing
#   ./scripts/eks-destroy-prep.sh --check-only  # READ-ONLY: only report what is holding the
#                                               # security groups. Safe on any cluster, including
#                                               # one you have no intention of destroying.
#
# Requires: kubectl, jq, aws CLI.
#
# Exits non-zero if anything is still holding on, so it can gate a destroy:
#   ./scripts/eks-destroy-prep.sh && terraform destroy

set -uo pipefail

DRY=0
CHECK_ONLY=0
REGION=""
TIMEOUT=600
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)    DRY=1; shift ;;
    --check-only) CHECK_ONLY=1; shift ;;
    --region)  REGION="${2:-}"; shift 2 ;;
    --timeout) TIMEOUT="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

ctx="$(kubectl config current-context 2>/dev/null || echo unknown)"
CLUSTER=""
if printf '%s' "$ctx" | grep -qE '^arn:aws[a-z-]*:eks:'; then
  REGION="${REGION:-$(printf '%s' "$ctx" | cut -d: -f4)}"
  CLUSTER="$(printf '%s' "$ctx" | sed 's|.*cluster/||')"
else
  CLUSTER="$(printf '%s' "$ctx" | sed 's|.*/||')"
fi
REGION="${REGION:-${AWS_REGION:-${AWS_DEFAULT_REGION:-}}}"

if [ -z "$CLUSTER" ] || [ -z "$REGION" ]; then
  echo "error: could not determine cluster and region from context '$ctx'; pass --region" >&2
  exit 2
fi

hr() { printf '\n== %s %s\n' "$1" "$(printf '=%.0s' $(seq 1 $((70 - ${#1}))))"; }
run() { if [ "$DRY" = 1 ]; then echo "  would run: $*"; else "$@"; fi; }

echo "EKS destroy preparation"
echo "cluster : $CLUSTER   region: $REGION"
[ "$DRY" = 1 ] && echo "MODE    : dry run, nothing will be changed"

if [ "$CHECK_ONLY" = 1 ]; then
  echo "MODE    : check only, READ-ONLY -- nothing is deleted and nothing is waited for"
fi

if [ "$CHECK_ONLY" = 0 ]; then
hr "1. DELETE THE OBJECTS THAT OWN AWS RESOURCES"
echo "  Ingress and Service type=LoadBalancer own load balancers. Deleting them lets the controller remove"
echo "  those while it is still running, which is the whole point of doing this before terraform starts."
ing="$(kubectl get ingress -A --no-headers 2>/dev/null | wc -l | tr -d ' ')"
svc="$(kubectl get svc -A -o json 2>/dev/null | jq '[.items[] | select(.spec.type == "LoadBalancer")] | length')"
echo "  found: ${ing} ingress, ${svc:-0} load balancer services"
if [ "${ing}" != "0" ]; then run kubectl delete ingress --all --all-namespaces --wait=false; fi
if [ "${svc:-0}" != "0" ]; then
  kubectl get svc -A -o json 2>/dev/null \
    | jq -r '.items[] | select(.spec.type == "LoadBalancer") | "\(.metadata.namespace) \(.metadata.name)"' \
    | while read -r ns name; do run kubectl delete svc -n "$ns" "$name" --wait=false; done
fi

hr "2. LET KARPENTER TERMINATE ITS OWN INSTANCES"
echo "  Deleting a NodePool cascades to its NodeClaims, and draining plus terminating each instance is the"
echo "  controller's job. Terraform never created those instances and cannot wait for them."
np="$(kubectl get nodepool --no-headers 2>/dev/null | wc -l | tr -d ' ')"
echo "  found: ${np} node pools"
if [ "${np}" != "0" ]; then run kubectl delete nodepool --all --wait=false; fi

hr "3. WAIT FOR THE AWS RESOURCES TO ACTUALLY BE GONE"
if [ "$DRY" = 1 ]; then
  echo "  would wait up to ${TIMEOUT}s for load balancers and node claims to disappear"
else
  deadline=$(( $(date +%s) + TIMEOUT ))
  while :; do
    nc="$(kubectl get nodeclaims --no-headers 2>/dev/null | wc -l | tr -d ' ')"
    lb="$(aws elbv2 describe-load-balancers --region "$REGION" 2>/dev/null \
          | jq --arg c "$CLUSTER" '[.LoadBalancers[] | select(.LoadBalancerName | startswith("k8s-"))] | length')"
    clb="$(aws elb describe-load-balancers --region "$REGION" 2>/dev/null \
          | jq '[.LoadBalancerDescriptions[]] | length')"
    printf '\r  nodeclaims=%-4s load balancers=%-4s classic=%-4s   ' "${nc}" "${lb:-?}" "${clb:-?}"
    if [ "${nc}" = "0" ] && [ "${lb:-0}" = "0" ]; then echo; echo "  clear"; break; fi
    if [ "$(date +%s)" -ge "$deadline" ]; then
      echo; echo "  TIMED OUT after ${TIMEOUT}s -- something is not finishing on its own. See section 4."
      break
    fi
    sleep 10
  done
fi

fi  # end of the mutating sections

hr "4. WHAT STILL REFERENCES THE CLUSTER SECURITY GROUPS"
echo "  This is the check that turns a fifteen-minute destroy failure into a ten-second answer. Anything"
echo "  listed here WILL block 'terraform destroy' with DependencyViolation on the security group."
sgs="$(aws ec2 describe-security-groups --region "$REGION" \
        --filters "Name=tag:kubernetes.io/cluster/${CLUSTER},Values=owned,shared" \
        --query 'SecurityGroups[].GroupId' --output text 2>/dev/null)"
if [ -z "$sgs" ]; then
  echo "  no cluster-tagged security groups found (already destroyed, or tagged differently)"
else
  blocked=0
  for sg in $sgs; do
    rows="$(aws ec2 describe-network-interfaces --region "$REGION" \
             --filters "Name=group-id,Values=${sg}" \
             --query 'NetworkInterfaces[].[NetworkInterfaceId,Status,Description]' --output text 2>/dev/null)"
    if [ -n "$rows" ]; then
      blocked=1
      echo "  ${sg} is still referenced by:"
      printf '%s\n' "$rows" | while IFS=$'\t' read -r eni status desc; do
        printf '    %-24s %-12s %s\n' "$eni" "$status" "${desc:-<no description>}"
      done
    fi
  done
  if [ "$blocked" = 0 ]; then
    echo "  nothing -- the security groups are free and the destroy will not stall on them"
  else
    echo
    echo "  The description names the owner, and that determines the fix:"
    echo "    'ELB app/k8s-...'   an orphaned load balancer. Delete it; its ENIs go with it."
    echo "    'aws-K8S-i-...'     a CNI interface from an instance that no longer exists:"
    echo "                          aws ec2 detach-network-interface --region ${REGION} --attachment-id <id> --force"
    echo "                          aws ec2 delete-network-interface --region ${REGION} --network-interface-id <eni>"
    echo "    'Amazon EKS ...'    a cluster interface; it clears when the cluster itself finishes deleting."
    exit 1
  fi
fi

hr "DONE"
if [ "$CHECK_ONLY" = 1 ]; then
  echo "  Nothing is holding the cluster security groups right now. Read-only: nothing was changed."
else
  echo "  Nothing is holding the cluster security groups. 'terraform destroy' should complete."
fi
