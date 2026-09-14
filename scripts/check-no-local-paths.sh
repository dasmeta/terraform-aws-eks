#!/usr/bin/env bash
#
# Fails if a local filesystem path has been committed to module code or examples.
#
# This module is published, so an absolute path such as /Users/<name>/... breaks every consumer and leaks a
# local environment into a public repository. Local paths are legitimate while testing unreleased changes;
# this check exists so such a state cannot be merged by accident.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

hits=$(grep -rnE '"(/Users/|/home/|/private/|\.\./\.\./\.\./)' \
        --include="*.tf" --include="*.tfvars" --include="*.yaml" \
        . 2>/dev/null | grep -v "/.terraform/" || true)

if [ -n "$hits" ]; then
  echo "Local filesystem paths found in committed configuration:"
  echo
  echo "$hits" | sed 's/^/  /'
  echo
  echo "These are fine while testing unreleased changes locally, but must not be merged."
  echo "Restore the published reference before opening a pull request."
  exit 1
fi
echo "no local filesystem paths in committed configuration"

# AWS account IDs are internal data and this module is public. They reach a repository the same way local
# paths do -- pasted from a working session while testing against a real account -- and are far harder to
# notice in review than a /Users/ path.
#
# Some 12-digit ids are legitimate and must not fail the check:
#   602401143452  AWS's own account for EKS-optimised AMIs and ECR addon images
#   123456789012  the placeholder AWS uses throughout its documentation
#   111111111111  the placeholder this repository uses in examples and tests
#   2222.../3333...  repeated-digit placeholders in vendored upstream documentation
echo "Checking for AWS account IDs..."
# A repeated single digit is a placeholder by construction, never a real account.
ALLOWED_ACCOUNTS='602401143452|123456789012|([0-9])\\1{11}'
acct_hits="$(grep -rnE '\b[0-9]{12}\b' \
  --include='*.tf' --include='*.md' --include='*.sh' --include='*.yaml' --include='*.yml' . 2>/dev/null \
  | grep -v '\.terraform/' | grep -v 'tfstate' | grep -vE '[0-9]{12}[0-9]' \
  | grep -vE "${ALLOWED_ACCOUNTS}" || true)"
if [ -n "$acct_hits" ]; then
  echo "$acct_hits"
  echo
  echo "A 12-digit number that is an AWS account ID must not be committed to this public module."
  echo "Replace it with a placeholder such as 111111111111, or parameterise it."
  exit 1
fi
echo "  none"
