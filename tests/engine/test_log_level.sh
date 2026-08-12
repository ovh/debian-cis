#!/bin/bash
# run-shellcheck
set -e
set -u

source tests/engine/lib.sh

write_test_script 
sed -i '/audit()/s|:;|echo $LOGLEVEL > "'$WORK_DIR'/tmp/loglevel.txt" ;|' "$WORK_DIR/bin/hardening/$DEFAULT_SCRIPT_NAME.sh"

"$REPO_ROOT/bin/hardening.sh" --allow-unsupported-distribution --audit --set-log-level error > /dev/null

assert_file_exists "$WORK_DIR/tmp/loglevel.txt"
loglevel=$(cat "$WORK_DIR/tmp/loglevel.txt")
[ "$loglevel" = "error" ] || fail "expected loglevel to be 'error', got: $loglevel"

echo "PASS: all '--set-log-level' test cases succeeded"

cleanup_tmpdir
