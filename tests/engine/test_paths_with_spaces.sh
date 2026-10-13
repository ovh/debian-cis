#!/bin/bash
# run-shellcheck
set -eu
source tests/engine/lib.sh
trap cleanup_tmpdir EXIT
write_test_script "$@"
mv "$WORK_DIR/versions/default" "$WORK_DIR/versions/with spaces"
export CIS_VERSIONS_DIR="$WORK_DIR/versions"
"$REPO_ROOT/bin/hardening.sh" --audit --set-version 'with spaces' --allow-unsupported-distribution --summary-json >"$WORK_DIR/tmp/output"
grep -q '"run_checks": 1' "$WORK_DIR/tmp/output" || fail 'script path split into multiple checks'
grep -q '"passed_checks": 1' "$WORK_DIR/tmp/output" || fail 'check in path with spaces did not run'
echo 'PASS: version paths containing spaces are preserved'
