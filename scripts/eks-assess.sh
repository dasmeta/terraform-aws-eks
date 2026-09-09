#!/usr/bin/env bash
#
# EKS cluster assessment. READ-ONLY: performs no mutation of any kind.
#
# Assesses the whole cluster, with node management (Karpenter) as the core because that is where most
# availability incidents originate. Also covers cluster/addon baseline, core addon resilience, workload
# disruption protection, and workload sizing.
#
# ZERO CONFIGURATION. Everything is discovered from the current kube context and AWS session:
#
#   ./scripts/eks-assess.sh
#
# Optional overrides, only if discovery gets something wrong:
#   --queue <name>    interruption queue (default: read from the karpenter deployment)
#   --region <name>   AWS region (default: parsed from the kube context ARN)
#
# Requires: kubectl, jq. Optional: aws CLI (queue metrics), metrics-server (live usage).

set -uo pipefail

QUEUE=""
REGION=""
while [ $# -gt 0 ]; do
  case "$1" in
    --queue)  QUEUE="${2:-}"; shift 2 ;;
    --region) REGION="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

ctx="$(kubectl config current-context 2>/dev/null || echo unknown)"

# Discover cluster, region and account from the context ARN when it is one (eksctl/aws-cli style):
#   arn:aws:eks:<region>:<account>:cluster/<name>
CLUSTER=""; ACCOUNT=""
if printf '%s' "$ctx" | grep -qE '^arn:aws[a-z-]*:eks:'; then
  REGION="${REGION:-$(printf '%s' "$ctx" | cut -d: -f4)}"
  ACCOUNT="$(printf '%s' "$ctx" | cut -d: -f5)"
  CLUSTER="$(printf '%s' "$ctx" | sed 's|.*cluster/||')"
fi
# Fall back to whatever the cluster calls itself, then to the raw context name.
[ -z "$CLUSTER" ] && CLUSTER="$(kubectl get nodes -o jsonpath='{.items[0].metadata.labels.alpha\.eksctl\.io/cluster-name}' 2>/dev/null || true)"
[ -z "$CLUSTER" ] && CLUSTER="$ctx"
[ -z "$REGION" ] && REGION="$(kubectl get nodes -o jsonpath='{.items[0].metadata.labels.topology\.kubernetes\.io/region}' 2>/dev/null || true)"
[ -z "$REGION" ] && REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"

# The interruption queue is recorded on the karpenter deployment itself; prefer that over guessing a name.
if [ -z "$QUEUE" ]; then
  QUEUE="$(kubectl -n karpenter get deploy karpenter \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="INTERRUPTION_QUEUE")].value}' 2>/dev/null || true)"
fi
[ -z "$QUEUE" ] && [ -n "$CLUSTER" ] && QUEUE="Karpenter-${CLUSTER}"

hr() { printf '\n== %s %s\n' "$1" "$(printf '=%.0s' $(seq 1 $((72 - ${#1}))))"; }

echo "EKS assessment"
echo "context : ${ctx}"
echo "cluster : ${CLUSTER:-unknown}   region: ${REGION:-unknown}   account: ${ACCOUNT:-unknown}"
echo "queue   : ${QUEUE:-not discovered}"
echo "date    : $(date -u +%Y-%m-%dT%H:%M:%SZ)"

hr "A1. CLUSTER AND NODE VERSIONS"
kubectl version -o json 2>/dev/null | jq -r '"  control plane : \(.serverVersion.gitVersion)"' || echo "  control plane : unknown"
echo "  node kubelet versions (a spread means nodes are not being rotated):"
kubectl get nodes -o json 2>/dev/null | jq -r '[.items[].status.nodeInfo.kubeletVersion] | group_by(.)
  | map({v: .[0], n: length}) | sort_by(-.n)[] | "    \(.n)x \(.v)"'
echo "  node OS images:"
kubectl get nodes -o json 2>/dev/null | jq -r '[.items[].status.nodeInfo.osImage] | group_by(.)
  | map({i: .[0], n: length}) | sort_by(-.n)[] | "    \(.n)x \(.i)"'

hr "A2. CLUSTER SCALE"
printf '  nodes_total     : %s\n' "$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')"
printf '  nodes_karpenter : %s\n' "$(kubectl get nodes -l karpenter.sh/nodepool --no-headers 2>/dev/null | wc -l | tr -d ' ')"
printf '  nodeclaims      : %s\n' "$(kubectl get nodeclaims --no-headers 2>/dev/null | wc -l | tr -d ' ')"
printf '  pods_total      : %s\n' "$(kubectl get pods -A --no-headers 2>/dev/null | wc -l | tr -d ' ')"
printf '  namespaces      : %s\n' "$(kubectl get ns --no-headers 2>/dev/null | wc -l | tr -d ' ')"
printf '  nodepools       : %s\n' "$(kubectl get nodepool --no-headers 2>/dev/null | wc -l | tr -d ' ')"

hr "A3. STORAGE CLASSES (gp2 is slower and pricier than gp3 for the same money)"
kubectl get storageclass -o json 2>/dev/null | jq -r '.items[]
  | "  \(.metadata.name)  provisioner=\(.provisioner)  reclaim=\(.reclaimPolicy)  binding=\(.volumeBindingMode)"
    + (if (.metadata.annotations["storageclass.kubernetes.io/is-default-class"] == "true") then "  <-- DEFAULT" else "" end)'
echo "  note: WaitForFirstConsumer binding avoids provisioning a volume in a zone with no capacity for the pod"

hr "B1. CORE ADDON RESILIENCE (these fail quietly and take everything with them)"
for d in kube-system/coredns kube-system/metrics-server kube-system/ebs-csi-controller kube-system/aws-load-balancer-controller; do
  ns="${d%%/*}"; name="${d##*/}"
  out=$(kubectl -n "$ns" get deploy "$name" -o json 2>/dev/null | jq -r '"replicas=\(.spec.replicas) available=\(.status.availableReplicas // 0)"')
  [ -n "$out" ] && printf '  %-42s %s\n' "$d" "$out"
done
echo "  coredns PDB:"
kubectl -n kube-system get pdb -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | test("coredns|dns"))
  | "    \(.metadata.name)  allowed=\(.status.disruptionsAllowed) expected=\(.status.expectedPods)"' || true
kubectl -n kube-system get pdb -o json 2>/dev/null | jq -e '[.items[] | select(.metadata.name | test("coredns|dns"))] | length > 0' >/dev/null 2>&1 \
  || echo "    NONE -- a node drain can take every coredns replica at once, which breaks name resolution cluster-wide"

hr "B2. CLUSTER AUTOSCALER (must not run alongside karpenter)"
ca=$(kubectl get deploy -A -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | test("cluster-autoscaler"))
  | "  FOUND  \(.metadata.namespace)/\(.metadata.name) replicas=\(.spec.replicas)"')
if [ -n "$ca" ]; then
  echo "$ca"
  echo "    Both scaling the same nodes causes fighting: one adds capacity the other removes."
else
  echo "  none (correct when karpenter manages nodes)"
fi

hr "B3. ADMISSION WEBHOOKS THAT CAN WEDGE THE CLUSTER"
echo "  A webhook with failurePolicy=Fail REJECTS the API calls it intercepts whenever it has no healthy"
echo "  backend. With one backend, a single eviction -- spot reclaim, consolidation, node upgrade -- is enough,"
echo "  and the rejections hit whatever the webhook matches, commonly pod creation across the cluster. The"
echo "  workload that cannot start then looks like the fault, so this is slow to diagnose."
echo "  It also blocks UNINSTALL of the component that owns it: the pods go, the webhook stays registered,"
echo "  and the cleanup it needs is rejected by itself. That presents as a helm delete that never finishes."
found=0
while IFS='|' read -r cfg ns svc; do
  [ -z "$cfg" ] && continue
  n=$(kubectl -n "$ns" get endpoints "$svc" -o json 2>/dev/null | jq '[.subsets[]?.addresses[]?] | length' 2>/dev/null)
  n=${n:-0}
  found=1
  if [ "$n" -lt 2 ]; then
    printf '  AT RISK  %-48s backends=%s  (%s/%s)\n' "$cfg" "$n" "$ns" "$svc"
  else
    printf '  ok       %-48s backends=%s  (%s/%s)\n' "$cfg" "$n" "$ns" "$svc"
  fi
done < <(kubectl get validatingwebhookconfigurations,mutatingwebhookconfigurations -o json 2>/dev/null | jq -r '
  .items[] | .metadata.name as $cfg | .webhooks[]?
  | select(.failurePolicy == "Fail")
  | select(.clientConfig.service != null)
  | "\($cfg)|\(.clientConfig.service.namespace)|\(.clientConfig.service.name)"' | sort -u)
[ "$found" = 0 ] && echo "  none with failurePolicy=Fail"

hr "C1. KARPENTER CONTROLLER (if this is down, nothing drains)"
kubectl -n karpenter get deploy karpenter -o json 2>/dev/null | jq -r '
  "replicas_desired: \(.spec.replicas)",
  "image           : \(.spec.template.spec.containers[0].image)",
  "resources       : \(.spec.template.spec.containers[0].resources)"' || echo "  karpenter deployment not found"
kubectl -n karpenter get pod -l app.kubernetes.io/name=karpenter -o json 2>/dev/null | jq -r '
  .items[] | "pod \(.metadata.name)  ready=\(.status.containerStatuses[0].ready)  restarts=\(.status.containerStatuses[0].restartCount)  lastTerminated=\(.status.containerStatuses[0].lastState.terminated.reason // "none")  priority=\(.spec.priorityClassName)  node=\(.spec.nodeName)"'
echo "-- live usage (needs metrics-server); compare against the limits above"
kubectl top pod -n karpenter --no-headers 2>/dev/null || echo "  kubectl top unavailable"

hr "C2. CONTROLLER SIZING CONTEXT (memory scales with node and pod counts)"
printf 'nodes_total      : %s\n' "$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')"
printf 'nodes_karpenter  : %s\n' "$(kubectl get nodes -l karpenter.sh/nodepool --no-headers 2>/dev/null | wc -l | tr -d ' ')"
printf 'nodeclaims       : %s\n' "$(kubectl get nodeclaims --no-headers 2>/dev/null | wc -l | tr -d ' ')"
printf 'pods_total       : %s\n' "$(kubectl get pods -A --no-headers 2>/dev/null | wc -l | tr -d ' ')"
printf 'nodepools        : %s\n' "$(kubectl get nodepool --no-headers 2>/dev/null | wc -l | tr -d ' ')"

hr "C3. CONTROLLER-ELIGIBLE NODES (managed node group only; karpenter nodes cannot host it)"
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

hr "D1. AMI SELECTION (an id: means replacement can trigger with no config change)"
kubectl get ec2nodeclass -o json 2>/dev/null | jq -r '.items[] | "\(.metadata.name): amiFamily=\(.spec.amiFamily // "unset") terms=\(.spec.amiSelectorTerms)"'
echo "-- node OS images (confirms the family an alias must preserve):"
kubectl get nodes -o json 2>/dev/null | jq -r '[.items[].status.nodeInfo.osImage] | group_by(.) | map({image: .[0], count: length}) | .[] | "  \(.count)x \(.image)"'
echo "-- kubelet versions (a spread means nodes are not being rotated):"
kubectl get nodes -o json 2>/dev/null | jq -r '[.items[].status.nodeInfo.kubeletVersion] | group_by(.) | map({v: .[0], count: length}) | .[] | "  \(.count)x \(.v)"'

hr "D2. DISRUPTION POSTURE"
kubectl get nodepool -o json 2>/dev/null | jq -r '.items[] |
  "\(.metadata.name):
     consolidationPolicy=\(.spec.disruption.consolidationPolicy // "unset")  consolidateAfter=\(.spec.disruption.consolidateAfter // "unset")  expireAfter=\(.spec.template.spec.expireAfter // "unset")
     budgets=\(.spec.disruption.budgets // [])"'
echo "-- ALWAYS-ON blocks (nodes:0 with no schedule) stop ALL voluntary disruption incl. AMI patching:"
kubectl get nodepool -o json 2>/dev/null | jq -r '.items[] | .metadata.name as $n |
  (.spec.disruption.budgets // [])[] | select(.nodes == "0" and (has("schedule") | not)) | "  BLOCKED  \($n)"'

hr "D3. NODE AGE (staleness from blocked disruption)"
kubectl get nodes -o json 2>/dev/null | jq -r --arg now "$(date -u +%s)" '
  .items[] | ((($now | tonumber) - (.metadata.creationTimestamp | fromdate)) / 86400 | floor) as $age
  | "  \($age)d  \(.metadata.name)  \(.status.nodeInfo.kubeletVersion)"' | sort -rn | head -10

hr "D4. NODES HELD BACK FROM REPLACEMENT (drifted, but correctly blocked -- needs a human)"
echo "  These nodes want to be replaced (usually a newer AMI) but karpenter is honouring a protection on"
echo "  them. That is the intended behaviour, NOT a fault. They will keep an older AMI until someone moves"
echo "  the workload deliberately -- typically cool the workload down, replace the node, bring it back."
echo
drifted=$(kubectl get nodeclaims -o json 2>/dev/null | jq -r '.items[]
  | select((.status.conditions // [])[] | select(.type == "Drifted" and .status == "True"))
  | "\(.status.nodeName // .metadata.name)"' 2>/dev/null)
if [ -z "$drifted" ]; then
  echo "  no drifted nodes"
else
  for n in $drifted; do
    echo "  DRIFTED  $n"
    # pods asking not to be moved
    kubectl get pods -A --field-selector "spec.nodeName=$n" -o json 2>/dev/null | jq -r '.items[]
      | select(.metadata.annotations["karpenter.sh/do-not-disrupt"] == "true")
      | "      holds it: \(.metadata.namespace)/\(.metadata.name)  (karpenter.sh/do-not-disrupt)"'
    # budgets that currently permit nothing, for workloads on this node
    kubectl get pods -A --field-selector "spec.nodeName=$n" -o json 2>/dev/null \
      | jq -r '.items[] | .metadata.namespace' | sort -u | while read -r ns; do
        kubectl -n "$ns" get pdb -o json 2>/dev/null | jq -r --arg ns "$ns" '.items[]
          | select(.status.disruptionsAllowed == 0)
          | "      holds it: \($ns)/\(.metadata.name)  (PDB allows 0 evictions)"'
      done
  done
  echo
  echo "  If a node appears here for longer than your patching tolerance, act on it -- it is not going to"
  echo "  resolve on its own. A PDB permitting 0 evictions (section E1) is a defect and should be fixed;"
  echo "  a do-not-disrupt annotation is a deliberate choice and needs the workload's own replacement flow."
fi

hr "E1. ZERO-EVICTION PDBs (block drains AND fail node group upgrades)"
found=$(kubectl get pdb -A -o json 2>/dev/null | jq -r '.items[] | select(.status.disruptionsAllowed == 0)
  | "  BLOCKING  \(.metadata.namespace)/\(.metadata.name)  allowed=0 expected=\(.status.expectedPods) current=\(.status.currentHealthy)"')
[ -n "$found" ] && echo "$found" || echo "  none"

hr "E2. PDB COVERAGE FOR MULTI-REPLICA WORKLOADS"
kubectl get deploy -A -o json 2>/dev/null | jq -r '.items[] | select((.spec.replicas // 0) >= 2)
  | "\(.metadata.namespace)/\(.metadata.name)"' | sort > /tmp/_ka_multi.txt
kubectl get pdb -A -o json 2>/dev/null | jq -r '.items[] | "\(.metadata.namespace)"' | sort -u > /tmp/_ka_pdbns.txt
printf 'multi_replica_deployments : %s\n' "$(wc -l < /tmp/_ka_multi.txt | tr -d ' ')"
printf 'namespaces_with_any_pdb   : %s\n' "$(wc -l < /tmp/_ka_pdbns.txt | tr -d ' ')"
echo "-- multi-replica deployments in namespaces with NO pdb at all:"
while read -r d; do ns="${d%%/*}"; grep -qx "$ns" /tmp/_ka_pdbns.txt || echo "  UNPROTECTED  $d"; done < /tmp/_ka_multi.txt | head -30

hr "E3. PDBs AT RISK FROM THE base 0.4.0 GUARD (minAvailable >= replica floor)"
echo "-- these renders will FAIL after the base chart upgrade and need correcting first:"
kubectl get pdb -A -o json 2>/dev/null | jq -r '.items[]
  | select(.spec.minAvailable != null and .status.expectedPods != null)
  | select((.spec.minAvailable | tostring | test("%") | not) and ((.spec.minAvailable | tonumber) >= .status.expectedPods))
  | "  AT RISK  \(.metadata.namespace)/\(.metadata.name)  minAvailable=\(.spec.minAvailable) expectedPods=\(.status.expectedPods)"'

hr "E4. STATEFUL / SINGLETON WORKLOADS ON SPOT"
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

hr "E5. SINGLETON STATEFULSETS (slow RWO reattach on eviction)"
kubectl get sts -A -o json 2>/dev/null | jq -r '.items[] | select((.spec.replicas // 0) <= 1)
  | "  SINGLETON  \(.metadata.namespace)/\(.metadata.name)  replicas=\(.spec.replicas)"' | head -20

hr "E6. WORKLOADS WITH NO CPU/MEMORY REQUESTS (karpenter sizes nodes from REQUESTS)"
kubectl get pods -A -o json 2>/dev/null | jq -r '
  [ .items[] | select(.metadata.ownerReferences[0].kind != "DaemonSet")
    | select( any(.spec.containers[]; (.resources.requests.cpu // "") == "" or (.resources.requests.memory // "") == "") )
    | "\(.metadata.namespace)/\(.metadata.ownerReferences[0].name // .metadata.name)" ]
  | unique | .[]' 2>/dev/null | head -25 | sed 's/^/  MISSING  /'
echo "  (a pod with no requests contributes nothing to sizing, so karpenter under-provisions and"
echo "   the pod pends after every disruption -- this is a common cause of slow recovery)"

hr "E7. SINGLE-REPLICA DEPLOYMENTS OUTSIDE SYSTEM NAMESPACES"
kubectl get deploy -A -o json 2>/dev/null | jq -r '.items[]
  | select((.spec.replicas // 0) == 1)
  | select(.metadata.namespace | test("^(kube-system|kube-public|kube-node-lease|karpenter|linkerd|cert-manager)$") | not)
  | "  SINGLE  \(.metadata.namespace)/\(.metadata.name)"' | head -25
echo "  (a single replica cannot be protected by a PodDisruptionBudget at all: any drain takes it down."
echo "   For an APPLICATION, raise it to 2. For a CONTROLLER that must not run twice -- external-dns and"
echo "   most operators without leader election -- a second replica causes conflicting writes and is the"
echo "   wrong fix; put it on protected on-demand capacity instead, or accept the restart.)"

hr "F1. INSTANCE TYPE MIX (burstable t-family throttles under load and is interrupted more often)"
kubectl get nodes -L node.kubernetes.io/instance-type,karpenter.sh/capacity-type,karpenter.sh/nodepool -o json 2>/dev/null | jq -r '
  [.items[] | {
     type: (.metadata.labels["node.kubernetes.io/instance-type"] // "unknown"),
     cap:  (.metadata.labels["karpenter.sh/capacity-type"] // "managed")
   }]
  | group_by(.type + "/" + .cap)
  | map({k: (.[0].type + "  " + .[0].cap), n: length})
  | sort_by(-.n)[] | "  \(.n)x  \(.k)"'
echo "-- family split (t = burstable; c = compute 1:2; m = general 1:4; r = memory 1:8):"
kubectl get nodes -o json 2>/dev/null | jq -r '
  [.items[] | (.metadata.labels["node.kubernetes.io/instance-type"] // "unknown") | split(".")[0] | .[0:1]]
  | group_by(.) | map({f: .[0], n: length}) | sort_by(-.n)[] | "  \(.n)x  family=\(.f)"'

hr "F2. CPU vs MEMORY RESERVATION BALANCE (a large gap means the wrong instance shape)"
echo "  node                                          cpu_req   mem_req"
for n in $(kubectl get nodes -o name 2>/dev/null | sed 's|node/||'); do
  line=$(kubectl describe node "$n" 2>/dev/null | awk '
    /Allocated resources/{f=1}
    f && $1=="cpu"{c=$3}
    f && $1=="memory"{m=$3; exit}
    END{print c, m}')
  printf "  %-44s %s\n" "$n" "$line"
done
echo "  (percentages are of allocatable. cpu% far above mem% means nodes run out of CPU while memory sits idle,"
echo "   so a lower memory-per-core shape -- c family at 1:2 -- fits better than t/m at 1:4)"

if [ -n "$QUEUE" ]; then
  hr "G1. INTERRUPTION QUEUE BACKLOG (>120s means drains are being missed)"
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
  hr "G1. INTERRUPTION QUEUE BACKLOG -- SKIPPED"
  echo "  the queue could not be discovered from the karpenter deployment; pass --queue <name>"
fi

rm -f /tmp/_ka_multi.txt /tmp/_ka_pdbns.txt /tmp/_ka_spot.txt
echo
echo "== done. read-only; nothing was changed."
