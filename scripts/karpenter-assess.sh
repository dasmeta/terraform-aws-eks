#!/usr/bin/env bash
#
# Karpenter readiness assessment. READ-ONLY: performs no mutation of any kind.
#
# Collects, for the currently selected kube context, everything needed to decide how and in what order to
# adopt the Karpenter stability baseline. Run once per cluster and keep the output.
#
# Usage:
#   ./scripts/karpenter-assess.sh                        # kube checks only
#   ./scripts/karpenter-assess.sh --queue Karpenter-eks-prod --region eu-central-1
#
# Requires: kubectl, jq. Optional: aws (for queue metrics), kubectl top (metrics-server).

set -uo pipefail

QUEUE=""
REGION="${AWS_REGION:-eu-central-1}"
while [ $# -gt 0 ]; do
  case "$1" in
    --queue)  QUEUE="${2:-}"; shift 2 ;;
    --region) REGION="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

ctx="$(kubectl config current-context 2>/dev/null || echo unknown)"
hr() { printf '\n== %s %s\n' "$1" "$(printf '=%.0s' $(seq 1 $((66 - ${#1}))))"; }
echo "Karpenter assessment"
echo "context : ${ctx}"
echo "date    : $(date -u +%Y-%m-%dT%H:%M:%SZ)"

hr "1. CONTROLLER"
kubectl -n karpenter get deploy karpenter -o json 2>/dev/null | jq -r '
  "replicas_desired: \(.spec.replicas)",
  "image           : \(.spec.template.spec.containers[0].image)",
  "resources       : \(.spec.template.spec.containers[0].resources)"' || echo "  karpenter deployment not found"
kubectl -n karpenter get pod -l app.kubernetes.io/name=karpenter -o json 2>/dev/null | jq -r '
  .items[] | "pod \(.metadata.name)  ready=\(.status.containerStatuses[0].ready)  restarts=\(.status.containerStatuses[0].restartCount)  lastTerminated=\(.status.containerStatuses[0].lastState.terminated.reason // "none")  priority=\(.spec.priorityClassName)  node=\(.spec.nodeName)"'
echo "-- live usage (needs metrics-server); compare against the limits above"
kubectl top pod -n karpenter --no-headers 2>/dev/null || echo "  kubectl top unavailable"

hr "2. CLUSTER SCALE (for controller sizing)"
printf 'nodes_total      : %s\n' "$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')"
printf 'nodes_karpenter  : %s\n' "$(kubectl get nodes -l karpenter.sh/nodepool --no-headers 2>/dev/null | wc -l | tr -d ' ')"
printf 'nodeclaims       : %s\n' "$(kubectl get nodeclaims --no-headers 2>/dev/null | wc -l | tr -d ' ')"
printf 'pods_total       : %s\n' "$(kubectl get pods -A --no-headers 2>/dev/null | wc -l | tr -d ' ')"
printf 'nodepools        : %s\n' "$(kubectl get nodepool --no-headers 2>/dev/null | wc -l | tr -d ' ')"

hr "3. CONTROLLER-ELIGIBLE NODES (managed node group only; karpenter nodes cannot host it)"
# NOTE: `kubectl get -L` pads a missing label with an empty trailing field, which awk collapses when
# splitting on whitespace, so $(NF) landed on the zone column and this check silently matched nothing.
# Select on the label via jq instead, which does not depend on column position.
kubectl get nodes -o json 2>/dev/null | jq -r '.items[]
  | select((.metadata.labels["karpenter.sh/nodepool"] // "") == "")
  | "  ELIGIBLE  zone=\(.metadata.labels["topology.kubernetes.io/zone"] // "unknown")  \(.metadata.name)"'
echo "-- distinct zones among eligible nodes (need >= 2 for karpenter replicas=2):"
kubectl get nodes -o json 2>/dev/null | jq -r '[.items[]
  | select((.metadata.labels["karpenter.sh/nodepool"] // "") == "")
  | .metadata.labels["topology.kubernetes.io/zone"] // "unknown"] | unique | .[]' | sed 's/^/  /'

hr "4. AMI SELECTION (an id: means replacement can trigger with no config change)"
kubectl get ec2nodeclass -o json 2>/dev/null | jq -r '.items[] | "\(.metadata.name): amiFamily=\(.spec.amiFamily // "unset") terms=\(.spec.amiSelectorTerms)"'
echo "-- node OS images (confirms the family an alias must preserve):"
kubectl get nodes -o json 2>/dev/null | jq -r '[.items[].status.nodeInfo.osImage] | group_by(.) | map({image: .[0], count: length}) | .[] | "  \(.count)x \(.image)"'
echo "-- kubelet versions (a spread means nodes are not being rotated):"
kubectl get nodes -o json 2>/dev/null | jq -r '[.items[].status.nodeInfo.kubeletVersion] | group_by(.) | map({v: .[0], count: length}) | .[] | "  \(.count)x \(.v)"'

hr "5. DISRUPTION POSTURE"
kubectl get nodepool -o json 2>/dev/null | jq -r '.items[] |
  "\(.metadata.name):
     consolidationPolicy=\(.spec.disruption.consolidationPolicy // "unset")  consolidateAfter=\(.spec.disruption.consolidateAfter // "unset")  expireAfter=\(.spec.template.spec.expireAfter // "unset")
     budgets=\(.spec.disruption.budgets // [])"'
echo "-- ALWAYS-ON blocks (nodes:0 with no schedule) stop ALL voluntary disruption incl. AMI patching:"
kubectl get nodepool -o json 2>/dev/null | jq -r '.items[] | .metadata.name as $n |
  (.spec.disruption.budgets // [])[] | select(.nodes == "0" and (has("schedule") | not)) | "  BLOCKED  \($n)"'

hr "6. NODE AGE (staleness from blocked disruption)"
kubectl get nodes -o json 2>/dev/null | jq -r --arg now "$(date -u +%s)" '
  .items[] | ((($now | tonumber) - (.metadata.creationTimestamp | fromdate)) / 86400 | floor) as $age
  | "  \($age)d  \(.metadata.name)  \(.status.nodeInfo.kubeletVersion)"' | sort -rn | head -10

hr "7. ZERO-EVICTION PDBs (block drains AND fail node group upgrades)"
found=$(kubectl get pdb -A -o json 2>/dev/null | jq -r '.items[] | select(.status.disruptionsAllowed == 0)
  | "  BLOCKING  \(.metadata.namespace)/\(.metadata.name)  allowed=0 expected=\(.status.expectedPods) current=\(.status.currentHealthy)"')
[ -n "$found" ] && echo "$found" || echo "  none"

hr "8. PDB COVERAGE FOR MULTI-REPLICA WORKLOADS"
kubectl get deploy -A -o json 2>/dev/null | jq -r '.items[] | select((.spec.replicas // 0) >= 2)
  | "\(.metadata.namespace)/\(.metadata.name)"' | sort > /tmp/_ka_multi.txt
kubectl get pdb -A -o json 2>/dev/null | jq -r '.items[] | "\(.metadata.namespace)"' | sort -u > /tmp/_ka_pdbns.txt
printf 'multi_replica_deployments : %s\n' "$(wc -l < /tmp/_ka_multi.txt | tr -d ' ')"
printf 'namespaces_with_any_pdb   : %s\n' "$(wc -l < /tmp/_ka_pdbns.txt | tr -d ' ')"
echo "-- multi-replica deployments in namespaces with NO pdb at all:"
while read -r d; do ns="${d%%/*}"; grep -qx "$ns" /tmp/_ka_pdbns.txt || echo "  UNPROTECTED  $d"; done < /tmp/_ka_multi.txt | head -30

hr "9. PDBs AT RISK FROM THE base 0.4.0 GUARD (minAvailable >= replica floor)"
echo "-- these renders will FAIL after the base chart upgrade and need correcting first:"
kubectl get pdb -A -o json 2>/dev/null | jq -r '.items[]
  | select(.spec.minAvailable != null and .status.expectedPods != null)
  | select((.spec.minAvailable | tostring | test("%") | not) and ((.spec.minAvailable | tonumber) >= .status.expectedPods))
  | "  AT RISK  \(.metadata.namespace)/\(.metadata.name)  minAvailable=\(.spec.minAvailable) expectedPods=\(.status.expectedPods)"'

hr "10. STATEFUL / SINGLETON WORKLOADS ON SPOT"
kubectl get nodes -l karpenter.sh/capacity-type=spot -o name 2>/dev/null | sed 's|node/||' > /tmp/_ka_spot.txt
if [ -s /tmp/_ka_spot.txt ]; then
  kubectl get pods -A -o json 2>/dev/null | jq -r '.items[] | select(.spec.nodeName != null)
    | "\(.metadata.namespace)/\(.metadata.name) \(.spec.nodeName) \(.metadata.ownerReferences[0].kind // "none")"' \
    | grep -Ff /tmp/_ka_spot.txt \
    | grep -viE 'daemonset' \
    | grep -iE 'mysql|postgres|maria|mongo|prometheus|grafana|redis|elastic|kafka|rabbit|kube-state-metrics|ingress|alertmanager|thanos|loki' \
    | sed 's/^/  ON-SPOT  /' | head -30
else
  echo "  no spot nodes found"
fi

hr "11. STATEFULSETS WITH RWO STORAGE (slow reattach on eviction)"
kubectl get sts -A -o json 2>/dev/null | jq -r '.items[] | select((.spec.replicas // 0) <= 1)
  | "  SINGLETON  \(.metadata.namespace)/\(.metadata.name)  replicas=\(.spec.replicas)"' | head -20

if [ -n "$QUEUE" ]; then
  hr "12. INTERRUPTION QUEUE BACKLOG (>120s means drains are being missed)"
  # CloudWatch caps a single call at 1440 datapoints. 30 days at a 3600s period is 720, comfortably under.
  # A wide period is fine here because the statistic is Maximum: a 300s spike still shows in its hour.
  aws cloudwatch get-metric-statistics --namespace AWS/SQS \
    --metric-name ApproximateAgeOfOldestMessage \
    --dimensions "Name=QueueName,Value=${QUEUE}" \
    --start-time "$(date -u -v-30d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%SZ)" \
    --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --period 3600 --statistics Maximum --region "$REGION" \
    --query 'sort_by(Datapoints,&Timestamp)[?Maximum>`0`].[Timestamp,Maximum]' --output text 2>/dev/null \
    | sed 's/^/  /' | tail -20 || echo "  query failed (check credentials, queue name, region)"
  echo "  (no rows means the controller kept up for every event in the 30 day window)"
  echo "  ANY value above 120 is a MISSED DRAIN: the spot interruption notice is only 120s."
else
  hr "12. INTERRUPTION QUEUE BACKLOG -- SKIPPED"
  echo "  re-run with: --queue Karpenter-<cluster-name> --region <region>"
fi

rm -f /tmp/_ka_multi.txt /tmp/_ka_pdbns.txt /tmp/_ka_spot.txt
echo
echo "== done. read-only; nothing was changed."
