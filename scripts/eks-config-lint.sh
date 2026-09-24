#!/usr/bin/env bash
#
# Static linter for a dasmeta EKS setup YAML (the eks.yaml in an infrastructure repo's
# 1-environments/<env>/ directory). READ-ONLY: reads the file, contacts nothing.
#
# Catches the misconfigurations that have caused production incidents, before they reach a cluster.
# Complements eks-assess.sh, which inspects a live cluster. This one needs no access at all,
# so it can run in CI or be pointed at any client repo.
#
# Usage:
#   ./scripts/eks-config-lint.sh <path-to-eks.yaml> [more.yaml ...]
#
# Exit codes: 0 = no findings, 1 = findings, 2 = usage error.
# Requires: yq (v4).

set -uo pipefail

[ $# -ge 1 ] || { sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2; }
command -v yq >/dev/null || { echo "error: yq (v4) is required" >&2; exit 2; }

findings=0
finding() { findings=$((findings+1)); printf '  [%s] %s\n      -> %s\n' "$1" "$2" "$3"; }

for FILE in "$@"; do
  [ -f "$FILE" ] || { echo "skip (not a file): $FILE"; continue; }
  echo "==============================================================="
  echo "FILE: $FILE"
  echo "==============================================================="

  q() { yq -r "$1 // \"\"" "$FILE" 2>/dev/null; }

  # Fail loudly rather than reporting empty findings. These files commonly reference YAML anchors defined in
  # a sibling file (provider aliases, account defaults), which yq cannot resolve when given one file alone.
  # Without this check every query silently returns empty and the file looks clean when it was never read.
  if ! parse_err=$(yq -r '.' "$FILE" 2>&1 >/dev/null); then
    echo "  CANNOT PARSE -- no checks were run against this file."
    echo "      ${parse_err}"
    if printf '%s' "$parse_err" | grep -q "unknown anchor"; then
      echo "      This file uses a YAML anchor defined elsewhere. Concatenate the defining file first, e.g."
      echo "        cat <dir>/0-globals.yaml \"$FILE\" | ./scripts/eks-config-lint.sh /dev/stdin"
      echo "      or lint the rendered output instead of the source."
    fi
    echo
    findings=$((findings+1))
    continue
  fi

  modver=$(yq -r '.version // ""' "$FILE" 2>/dev/null)
  cluster=$(q '.variables.cluster_name')
  kenabled=$(q '.variables.karpenter.enabled')
  echo "  cluster=${cluster:-?}  module_version=${modver:-?}  karpenter_enabled=${kenabled:-?}"
  echo

  [ "$kenabled" = "false" ] && { echo "  karpenter disabled; nothing to check."; echo; continue; }

  # --- controller replicas -------------------------------------------------
  replicas=$(q '.variables.karpenter.configs.replicas')
  if [ "$replicas" = "1" ]; then
    finding HIGH "karpenter.configs.replicas = 1" \
      "A single controller has no failover during any restart. While it restarts the interruption queue backs up, and a backlog past the 120s spot notice means nodes are reclaimed undrained. Use 2, which needs 2 managed-node-group nodes in 2 AZs."
  fi

  # --- managed node group able to host 2 replicas ---------------------------
  ngcount=$(yq -r '[.variables.node_groups // {} | to_entries[]] | length' "$FILE" 2>/dev/null)
  maxdesired=$(yq -r '[.variables.node_groups // {} | to_entries[] | .value.desired_size // 0] | max // 0' "$FILE" 2>/dev/null)
  if [ "${ngcount:-0}" -gt 0 ] && [ "${maxdesired:-0}" -lt 2 ]; then
    finding HIGH "largest managed node group desired_size = ${maxdesired}" \
      "Karpenter's chart excludes its own nodes (karpenter.sh/nodepool DoesNotExist), so only managed-node-group nodes can host the controller. Fewer than 2 makes replicas=2 impossible. Total cluster node count is irrelevant."
  fi

  # --- resource_configs_defaults nesting ------------------------------------
  badkeys=$(yq -r '(.variables.karpenter.resource_configs_defaults // {}) | keys | map(select(. != "default" and . != "gpu")) | join(", ")' "$FILE" 2>/dev/null)
  if [ -n "$badkeys" ]; then
    finding HIGH "resource_configs_defaults has top-level key(s): $badkeys" \
      "Terraform SILENTLY DROPS object attributes the target type does not declare, so these never take effect and the module default applies instead -- with no error at validate, plan or apply. Nest under 'default:' or 'gpu:'."
  fi

  # --- always-on disruption block -------------------------------------------
  blocked=$(yq -r '
    [ (.variables.karpenter.resource_configs.nodePools // {}) | to_entries[]
      | select( [ (.value.disruption.budgets // [])[] | select(.nodes == "0" and (has("schedule") | not)) ] | length > 0 )
      | .key ] | join(", ")' "$FILE" 2>/dev/null)
  if [ -n "$blocked" ]; then
    finding HIGH "always-on 'nodes: 0' budget on pool(s): $blocked" \
      "With no schedule/duration this is permanent, so it stops ALL voluntary disruption including AMI drift remediation -- nodes stop being patched. One cluster reached 102-day-old nodes still on the previous kubelet minor. Use a scheduled window instead."
  fi

  # --- burstable instance family --------------------------------------------
  reqs=$(yq -r '(.variables.karpenter.resource_configs_defaults.default.requirements // []) | tojson' "$FILE" 2>/dev/null)
  if ! printf '%s' "$reqs" | grep -q "instance-category" && ! printf '%s' "$reqs" | grep -q "instance-family"; then
    finding MEDIUM "no instance-category or instance-family constraint" \
      "Without one, the cheapest fit is often a burstable t-family node. Those throttle to a fraction of their vCPU under sustained load and sit in the most contended spot pools, so they are interrupted more often. Constrain to c/m/r for production workloads."
  fi

  # --- consolidation aggressiveness -----------------------------------------
  yq -r '(.variables.karpenter.resource_configs.nodePools // {}) | to_entries[]
         | select((.value.disruption.consolidateAfter // "") | test("^[0-9]m$"))
         | .key + " " + .value.disruption.consolidateAfter' "$FILE" 2>/dev/null \
  | while read -r pool after; do
      n="${after%m}"
      [ -n "$n" ] && [ "$n" -lt 10 ] 2>/dev/null && \
        printf '  [MEDIUM] pool "%s" consolidateAfter = %s\n      -> %s\n' "$pool" "$after" \
          "A brief utilisation dip is enough to trigger node removal. Repeatedly implicated in replicas being evicted too close together. 15m or more is safer."
    done

  # --- expireAfter with a finite value --------------------------------------
  expiring=$(yq -r '[ (.variables.karpenter.resource_configs.nodePools // {}) | to_entries[]
    | select((.value.template.spec.expireAfter // "Never") != "Never") | .key ] | join(", ")' "$FILE" 2>/dev/null)
  if [ -n "$expiring" ]; then
    finding MEDIUM "finite expireAfter on pool(s): $expiring" \
      "Node expiry is NOT gated by disruption budgets or windows, so expiring nodes are replaced unpaced and during traffic hours. Prefer AMI drift, which IS budget-paced."
  fi

  # --- disruption windows present -------------------------------------------
  haswindow=$(yq -r '[ (.variables.karpenter.resource_configs.nodePools // {}) | to_entries[]
    | (.value.disruption.budgets // [])[] | select(has("schedule")) ] | length' "$FILE" 2>/dev/null)
  dwin=$(yq -r '[(.variables.karpenter.resource_configs_defaults.default.disruption.budgets // [])[] | select(has("schedule"))] | length' "$FILE" 2>/dev/null)
  if [ "${haswindow:-0}" = "0" ] && [ "${dwin:-0}" = "0" ]; then
    finding LOW "no scheduled disruption window" \
      "Voluntary consolidation can run during peak traffic. Module >= 2.30.0 ships a default window; on older versions set budgets with schedule/duration per pool. Schedules are UTC only -- karpenter has no timezone support."
  fi

  echo
done

echo "==============================================================="
if [ "$findings" -eq 0 ]; then
  echo "no findings"
  exit 0
fi
echo "$findings finding(s)"
echo
echo "Severity meaning:"
echo "  HIGH   -- has caused a production incident in this fleet"
echo "  MEDIUM -- materially raises the chance of one"
echo "  LOW    -- worth fixing, no incident traced to it yet"
exit 1
