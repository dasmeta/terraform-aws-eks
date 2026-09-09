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
