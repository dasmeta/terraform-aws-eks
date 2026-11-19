#!/usr/bin/env bash
# Runs the negative test cases in this directory and passes only if EVERY run fails with the expected
# error. `terraform test` has no way to expect an error raised inside a child module, so the assertion is
# made here instead: on the exit code, the per-run result, and the guard's message.
#
# Credential-free: all providers are mocked. Run from anywhere:  tests/negative/run.sh
set -euo pipefail

cd "$(dirname "$0")/../.."
dir=tests/negative

terraform init -backend=false -input=false -test-directory="$dir" >/dev/null

# One case per file, because terraform test skips the rest of a file after a failed run. The version a case
# plans is in its file name, and the error must name that version.
files=$(ls "$dir"/al2_guard_*.tftest.hcl 2>/dev/null || true)
[ -n "$files" ] || { echo "no negative test files found in $dir" >&2; exit 1; }

status=0
for f in $files; do
  version=$(basename "$f" .tftest.hcl | sed -E 's/^al2_guard_([0-9]+)_([0-9]+)$/\1.\2/')
  set +e
  out=$(terraform test -test-directory="$dir" -filter="$f" -no-color 2>&1)
  code=$?
  set -e

  if [ "$code" -eq 0 ]; then
    echo "FAIL $f: the plan succeeded, but the AL2 guard should have rejected it"; status=1
  elif ! grep -q "cluster_version $version has no Amazon Linux 2 AMI" <<<"$out" || ! grep -q "AL2_x86_64" <<<"$out"; then
    echo "FAIL $f: the plan failed, but not with the AL2 guard's error for $version:"; echo "$out" | tail -20; status=1
  else
    echo "ok   $f: $version rejected by the AL2 guard"
  fi
done

exit $status
