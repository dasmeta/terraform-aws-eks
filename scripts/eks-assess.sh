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

# PREFLIGHT. Every check below reads the API server as `kubectl ... 2>/dev/null | jq`, a shape in which a
# FAILED read is indistinguishable from an EMPTY result. An expired token therefore rendered as a complete,
# confident report of a cluster with zero nodes, zero pods and every addon "NOT INSTALLED" -- which is also
# exactly what a destroyed cluster looks like. Refuse to emit a report at all rather than emit a false one.
#
# `kubectl version` cannot do this job: it exits 0 having printed only the client version, leaving
# serverVersion null. This asks for a resource, so it fails when the server is unreachable OR unauthorized.
if ! API_VERSION_JSON="$(kubectl get --raw /version 2>&1)"; then
  echo
  echo "FATAL: cannot read the kubernetes API server."
  echo "  context : ${ctx}"
  echo
  printf '%s\n' "$API_VERSION_JSON" | sed 's/^/  /'
  echo
  echo "  NO ASSESSMENT WAS PRODUCED, deliberately. Every check reads from this API server, and a failed"
  echo "  read looks identical to an empty one, so the report would have claimed this cluster is gone."
  echo "  Usually this is just an expired token. Refresh credentials and run again:"
  echo "    aws eks update-kubeconfig --name ${CLUSTER:-<cluster>} --region ${REGION:-<region>}"
  exit 1
fi
echo "date    : $(date -u +%Y-%m-%dT%H:%M:%SZ)"

hr "A1. CLUSTER AND NODE VERSIONS"
# Taken from the preflight response rather than `kubectl version`, which prints a null serverVersion and a
# non-zero exit on the same run, producing both a "null" line and an "unknown" line.
printf '%s' "$API_VERSION_JSON" | jq -r '"  control plane : \(.gitVersion)"'
echo "  node kubelet versions (a spread means nodes are not being rotated):"
kubectl get nodes -o json 2>/dev/null | jq -r '[.items[].status.nodeInfo.kubeletVersion] | group_by(.)
  | map({v: .[0], n: length}) | sort_by(-.n)[] | "    \(.n)x \(.v)"'
echo "  node OS images:"
kubectl get nodes -o json 2>/dev/null | jq -r '[.items[].status.nodeInfo.osImage] | group_by(.)
  | map({i: .[0], n: length}) | sort_by(-.n)[] | "    \(.n)x \(.i)"'

# Control plane and nodes differing is normal and reads as alarming, so say which kind it is rather than
# leaving the reader to compare two lists. A PATCH difference is routine -- EKS patches the control plane on
# its own and the node AMI follows later. A MINOR difference is the upgrade case, where the nodes are waiting
# on a drift roll that the disruption window may be holding.
cp_ver="$(printf '%s' "$API_VERSION_JSON" | jq -r '.gitVersion // empty' | sed 's/^v//;s/-.*//')"
node_vers="$(kubectl get nodes -o json 2>/dev/null | jq -r '[.items[].status.nodeInfo.kubeletVersion] | unique[]' | sed 's/^v//;s/-.*//')"
if [ -n "$cp_ver" ] && [ -n "$node_vers" ]; then
  cp_mm="$(printf '%s' "$cp_ver" | cut -d. -f1-2)"
  skew_minor=0; skew_patch=0; behind_minor=0
  total_nodes="$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')"
  # Iterated over lines rather than by word splitting, which the bash shebang provides but zsh does not --
  # a reader testing a snippet of this in their own shell would otherwise get a wrong answer silently.
  while IFS= read -r nv; do
    [ -z "$nv" ] && continue
    if [ "$(printf '%s' "$nv" | cut -d. -f1-2)" = "$cp_mm" ]; then :; else
      skew_minor=1
      # How many nodes sit on this older minor, so the line can say "1 of 6" rather than implying all.
      n="$(kubectl get nodes -o json 2>/dev/null | jq --arg v "$nv" '[.items[] | select((.status.nodeInfo.kubeletVersion | sub("^v";"") | sub("-.*";"")) == $v)] | length')"
      behind_minor=$((behind_minor + ${n:-0}))
    fi
    [ "$nv" = "$cp_ver" ] || skew_patch=1
  done <<< "$node_vers"
  if [ "$skew_minor" = 1 ]; then
    echo "  SKEW: ${behind_minor} of ${total_nodes} nodes are a MINOR version behind the control plane. Supported, but"
    echo "        they are waiting on an AMI drift roll -- check D4 and the disruption windows in D2 if it"
    echo "        is not progressing. A count well below the total means the roll is already under way."
  elif [ "$skew_patch" = 1 ]; then
    echo "  skew: nodes are a patch behind the control plane ($cp_ver). Routine -- EKS patches the control"
    echo "        plane on its own and the node AMI follows when AWS republishes it. Nothing to do."
  else
    echo "  control plane and nodes are on the same version"
  fi
fi

hr "A2. CLUSTER SCALE"
printf '  nodes_total     : %s\n' "$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')"
printf '  nodes_karpenter : %s\n' "$(kubectl get nodes -l karpenter.sh/nodepool --no-headers 2>/dev/null | wc -l | tr -d ' ')"
printf '  nodeclaims      : %s\n' "$(kubectl get nodeclaims --no-headers 2>/dev/null | wc -l | tr -d ' ')"
printf '  pods_total      : %s\n' "$(kubectl get pods -A --no-headers 2>/dev/null | wc -l | tr -d ' ')"
printf '  namespaces      : %s\n' "$(kubectl get ns --no-headers 2>/dev/null | wc -l | tr -d ' ')"
printf '  nodepools       : %s\n' "$(kubectl get nodepool --no-headers 2>/dev/null | wc -l | tr -d ' ')"

hr "A3. STORAGE CLASSES (gp2 is slower and pricier than gp3 for the same money)"
sc_json=$(kubectl get storageclass -o json 2>/dev/null)
csi_json=$(kubectl get csidrivers -o json 2>/dev/null)
echo "$sc_json" | jq -r '.items[]
  | "  \(.metadata.name)  provisioner=\(.provisioner)  reclaim=\(.reclaimPolicy)  binding=\(.volumeBindingMode)"
    + (if (.metadata.annotations["storageclass.kubernetes.io/is-default-class"] == "true") then "  <-- DEFAULT" else "" end)'
echo "  note: WaitForFirstConsumer binding avoids provisioning a volume in a zone with no capacity for the pod"

# A class is only usable if the driver behind it is registered, and the class object gives no sign either
# way -- it lists cleanly above whether or not anything can serve it. The in-tree kubernetes.io/aws-ebs
# provisioner has been removed from kubernetes, so the gp2 class every EKS cluster is created with now
# depends entirely on the EBS CSI driver: with the driver absent, CSI migration has nothing to migrate to
# and the class provisions nothing. Skipped when the csidrivers list could not be read, so that missing
# RBAC does not report every class as broken.
if [ -n "$csi_json" ]; then
  echo "$sc_json" | jq -r --argjson csi "$csi_json" '
    [$csi.items[].metadata.name] as $d
    | .items[]
    | . as $sc
    | (if   .provisioner == "kubernetes.io/aws-ebs" then "ebs.csi.aws.com"
       elif .provisioner == "kubernetes.io/aws-efs" then "efs.csi.aws.com"
       elif (.provisioner | startswith("kubernetes.io/")) then null
       else .provisioner end) as $need
    | select($need != null and ($d | index($need) | not))
    | "  UNUSABLE  \($sc.metadata.name) needs the \($need) driver, which is not registered here --"
      + " a PVC on this class stays Pending and provisions nothing"'
fi

# No default class at all is the quiet version of the same failure: nothing is reported as broken, and
# every PVC that omits storageClassName simply never binds.
if ! echo "$sc_json" | jq -e '[.items[]
     | select(.metadata.annotations["storageclass.kubernetes.io/is-default-class"] == "true")] | length > 0' >/dev/null 2>&1; then
  echo "  NO DEFAULT STORAGE CLASS -- a PVC that does not name a class will never bind. Anything that asks"
  echo "  for storage without setting storageClassName stays Pending indefinitely, with no event saying why."
fi

pvc_json=$(kubectl get pvc -A -o json 2>/dev/null)
if [ -n "$pvc_json" ]; then
  echo "$pvc_json" | jq -r '"  persistentvolumeclaims: \(.items | length) total, "
    + "\([.items[] | select(.status.phase != "Bound")] | length) not bound"'
  echo "$pvc_json" | jq -r '.items[] | select(.status.phase != "Bound")
    | "  PENDING PVC  \(.metadata.namespace)/\(.metadata.name) class=\(.spec.storageClassName // "(none -- wants the default)")"'
fi

hr "B1. CORE ADDON RESILIENCE (these fail quietly and take everything with them)"
# An absent addon used to print nothing at all, which made the most severe state the one state with no
# output. Absence is reported explicitly now, with what it costs -- some of these are a broken cluster and
# some are a deliberate choice, so the note carries the severity rather than the label.
for d in kube-system/coredns kube-system/metrics-server kube-system/ebs-csi-controller kube-system/aws-load-balancer-controller; do
  ns="${d%%/*}"; name="${d##*/}"
  out=$(kubectl -n "$ns" get deploy "$name" -o json 2>/dev/null | jq -r '"replicas=\(.spec.replicas) available=\(.status.availableReplicas // 0)"')
  if [ -n "$out" ]; then
    printf '  %-42s %s\n' "$d" "$out"
    continue
  fi
  case "$name" in
    coredns)
      why="name resolution is gone cluster-wide. This is a broken cluster, not a configuration choice" ;;
    metrics-server)
      why="no HPA scaling and no kubectl top; the live usage in section C1 comes back empty" ;;
    ebs-csi-controller)
      why="no EBS volume can be provisioned or attached. A fault only if anything here uses PVCs -- section A3 reports that" ;;
    aws-load-balancer-controller)
      why="Ingress and Service type=LoadBalancer objects are never reconciled" ;;
    *)
      why="not installed" ;;
  esac
  printf '  %-42s %s\n' "$d" "NOT INSTALLED -- $why"
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
echo "  These nodes want to be replaced -- usually a newer AMI -- and karpenter has not replaced them yet."
echo "  That is normally intended behaviour, NOT a fault. Check the causes in this order:"
echo "   1. A DISRUPTION WINDOW is open. Drift is voluntary disruption, so a budget of nodes:0 covering"
echo "      Drifted holds the roll until the window closes. Section D2 shows each pool's budgets. This is"
echo "      the usual answer right after a kubernetes version upgrade, which drifts every node at once."
echo "   2. A PodDisruptionBudget on this node permits no eviction. That is a DEFECT -- see section E1."
echo "   3. A pod carries karpenter.sh/do-not-disrupt. Deliberate; needs the workload own replacement flow."
echo "  Only 2 needs fixing. For 1, the roll proceeds on its own when the window closes."
echo
drifted=$(kubectl get nodeclaims -o json 2>/dev/null | jq -r '.items[]
  | select((.status.conditions // [])[] | select(.type == "Drifted" and .status == "True"))
  | "\(.status.nodeName // .metadata.name)"' 2>/dev/null)
if [ -z "$drifted" ]; then
  echo "  no drifted nodes"
else
  for n in $drifted; do
    pool=$(kubectl get node "$n" -o jsonpath='{.metadata.labels.karpenter\.sh/nodepool}' 2>/dev/null)
    echo "  DRIFTED  $n  nodepool=${pool:-unknown}  -- check that pool in D2"
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
echo "  A budget permitting nothing is a DEFECT unless somebody chose it. The base chart annotates the ones"
echo "  chosen deliberately -- a workload rolled by hand that automation must never evict -- so those are"
echo "  listed separately here rather than reported as faults forever."
found=$(kubectl get pdb -A -o json 2>/dev/null | jq -r '.items[]
  | select(.status.disruptionsAllowed == 0)
  | select((.metadata.annotations // {})["dasmeta.io/zero-evictions"] == null)
  | "  BLOCKING  \(.metadata.namespace)/\(.metadata.name)  allowed=0 expected=\(.status.expectedPods) current=\(.status.currentHealthy)"')
[ -n "$found" ] && echo "$found" || echo "  none"
deliberate=$(kubectl get pdb -A -o json 2>/dev/null | jq -r '.items[]
  | select(.status.disruptionsAllowed == 0)
  | select((.metadata.annotations // {})["dasmeta.io/zero-evictions"] != null)
  | "  DELIBERATE  \(.metadata.namespace)/\(.metadata.name)  allowed=0 expected=\(.status.expectedPods)"')
if [ -n "$deliberate" ]; then
  echo
  echo "  Declared deliberate via pdb.allowZeroEvictions. Not a fault, but the consequences still apply:"
  echo "  drains block on these, and a managed node group upgrade fails on their eviction. Plan node work"
  echo "  around them."
  echo "$deliberate"
fi

hr "E2. PDB COVERAGE FOR MULTI-REPLICA WORKLOADS"
kubectl get deploy -A -o json 2>/dev/null | jq -r '.items[] | select((.spec.replicas // 0) >= 2)
  | "\(.metadata.namespace)/\(.metadata.name)"' | sort > /tmp/_ka_multi.txt
kubectl get pdb -A -o json 2>/dev/null | jq -r '.items[] | "\(.metadata.namespace)"' | sort -u > /tmp/_ka_pdbns.txt
printf 'multi_replica_deployments : %s\n' "$(wc -l < /tmp/_ka_multi.txt | tr -d ' ')"
printf 'namespaces_with_any_pdb   : %s\n' "$(wc -l < /tmp/_ka_pdbns.txt | tr -d ' ')"
echo "-- multi-replica deployments in namespaces with NO pdb at all:"
while read -r d; do ns="${d%%/*}"; grep -qx "$ns" /tmp/_ka_pdbns.txt || echo "  UNPROTECTED  $d"; done < /tmp/_ka_multi.txt | head -30

hr "E3. PDBs AT RISK FROM THE base 0.4.0 GUARD (minAvailable >= replica floor)"
echo "  Read from the LIVE object, which is all that exists before the upgrade. That has one blind spot: a"
echo "  release whose values ALREADY set pdb.allowZeroEvictions renders fine on 0.4.0, but the released"
echo "  chart ignores that key so nothing here distinguishes it. Check the values of anything listed before"
echo "  assuming it needs changing -- if the flag is already there, it is a false alarm."
echo "-- these renders will FAIL after the base chart upgrade and need correcting first:"
kubectl get pdb -A -o json 2>/dev/null | jq -r '.items[]
  | select((.metadata.annotations // {})["dasmeta.io/zero-evictions"] == null)
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

hr "E8. BITNAMI IMAGES STILL POINTING AT THE RETIRED REPOSITORY"
echo "  Bitnami moved its free images to the \`bitnamilegacy\` repository. Pin the new path in each workload's"
echo "  OWN image config -- a values override, a chart upgrade -- and not with the kyverno mutating policy."
echo "  That policy was a stopgap for the cutover. Keeping it means every pod creation in the cluster depends"
echo "  on an admission webhook staying healthy (section B3) in order to get a working image reference."
hits=$(kubectl get pods -A -o json 2>/dev/null | jq -r '
  .items[] | .metadata.namespace as $ns
  | (.spec.containers[]?, .spec.initContainers[]?)
  | select(.image | test("(^|/)bitnami/"))
  | "  SWITCH  \($ns)  \(.image)"' | sort -u)
if [ -n "$hits" ]; then
  echo "$hits"
  echo "  -> replace the 'bitnami/' path with 'bitnamilegacy/' in the chart values for each of these,"
  echo "     then set kyverno.enabled = false (it is false by default from 2.30.0)."
else
  echo "  none -- no image references the retired repository, so the kyverno rewrite policy is not needed here"
fi

hr "F1. INSTANCE TYPE MIX (burstable t-family throttles under load and is interrupted more often)"
echo "  Read the POOL column with the capacity type. On-demand nodes in a pool that also permits spot are"
echo "  paying on-demand rates without being asked to -- usually spot capacity was unavailable for the"
echo "  shapes the pool allows, which is a signal to widen its instance requirements rather than a setting"
echo "  to change. On-demand in a pool that requires it is simply that pool working."
kubectl get nodes -o json 2>/dev/null | jq -r '
  [.items[] | {
     type: (.metadata.labels["node.kubernetes.io/instance-type"] // "unknown"),
     cap:  (.metadata.labels["karpenter.sh/capacity-type"] // "managed"),
     pool: (.metadata.labels["karpenter.sh/nodepool"] // "-- managed node group --")
   }]
  | group_by(.type + "/" + .cap + "/" + .pool)
  | map({t: .[0].type, c: .[0].cap, p: .[0].pool, n: length})
  | sort_by(-.n)[] | "  \(.n)x  \(.t | . + "                    " | .[0:18])\(.c | . + "            " | .[0:11]) pool=\(.p)"'
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
    | awk '{ printf "  %-26s %s seconds\n", $1, $2 }' | tail -20 || echo "  query failed (check credentials, queue name, region)"
  echo "  Timestamps are whatever your AWS CLI renders; the disruption windows in D2 are UTC ONLY, so"
  echo "  convert before correlating a backlog with a window."
  echo "  (no rows means the controller kept up for every event in the 30 day window)"
  echo "  ANY value above 120 is a MISSED DRAIN: the spot interruption notice is only 120s."
else
  hr "G1. INTERRUPTION QUEUE BACKLOG -- SKIPPED"
  echo "  the queue could not be discovered from the karpenter deployment; pass --queue <name>"
fi

if [ -n "${REGION}" ] && [ -n "${CLUSTER}" ]; then
  hr "G2. ORPHANED CNI NETWORK INTERFACES (leaked IPs, and a stuck destroy later)"
  echo "  The VPC CNI allocates secondary interfaces on each node to hand out pod IPs. When a node goes away"
  echo "  before the CNI detaches them -- every consolidation, every spot reclaim, every node group"
  echo "  replacement -- the interface is left behind in 'available' state. Nothing reclaims it: AWS does not"
  echo "  garbage-collect an available interface."
  echo
  echo "  Two consequences, and the first is the one that bites a running cluster:"
  echo "    - each one holds a private IP in its subnet, so a cluster with heavy churn quietly loses address"
  echo "      space and eventually cannot schedule pods, with nothing in kubernetes explaining why;"
  echo "    - at teardown they hold the node security group and 'terraform destroy' fails on it."
  # A failed query used to be swallowed and reported as "none" -- a clean bill of health on the one thing
  # that blocks a destroy, issued without having looked. Failure and emptiness are now separate outcomes.
  if ! orphans="$(aws ec2 describe-network-interfaces --region "$REGION" \
    --filters "Name=status,Values=available" \
    --query 'NetworkInterfaces[?starts_with(Description, `aws-K8S-i-`)].[NetworkInterfaceId,SubnetId,PrivateIpAddress,Description]' \
    --output text 2>&1)"; then
    echo "  QUERY FAILED -- this section was NOT checked, which is not the same as finding none:"
    printf '%s\n' "$orphans" | sed 's/^/    /' | head -5
  elif [ -z "$orphans" ]; then
    echo "  none"
  else
    n="$(printf '%s\n' "$orphans" | grep -c .)"
    printf '%s\n' "$orphans" | awk '{ printf "  ORPHAN  %-24s %-26s %-16s from %s\n", $1, $2, $3, $4 }' | head -25
    echo
    echo "  ${n} orphaned interface(s), each holding one private IP. The instance id is in the description,"
    echo "  so \`aws ec2 describe-instances --instance-ids <id>\` names the node it came from while that"
    echo "  instance is still visible. Each is 'available', meaning detached, so removal needs no detach"
    echo "  step and nothing is using it:"
    echo "    aws ec2 delete-network-interface --region ${REGION} --network-interface-id <eni-...>"
    echo "  Check the status and the aws-K8S-i- description first. An interface owned by a load balancer,"
    echo "  or still attached, is a symptom -- remove its owner instead."
  fi
fi

rm -f /tmp/_ka_multi.txt /tmp/_ka_pdbns.txt /tmp/_ka_spot.txt
echo
echo "== done. read-only; nothing was changed."
