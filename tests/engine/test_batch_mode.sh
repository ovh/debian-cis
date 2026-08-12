#!/bin/bash
# run-shellcheck
set -e
set -u

source tests/engine/lib.sh

write_test_script 
sed -i '/audit()/s|:;|echo $LOGLEVEL > "'$WORK_DIR'/tmp/loglevel.txt" ;|' "$WORK_DIR/bin/hardening/$DEFAULT_SCRIPT_NAME.sh"

# --set-hardening-level enable requested level and below
"$REPO_ROOT/bin/hardening.sh" --allow-unsupported-distribution --audit --batch > /dev/null

assert_file_exists "$WORK_DIR/tmp/loglevel.txt"
loglevel=$(cat "$WORK_DIR/tmp/loglevel.txt")
[ "$loglevel" = "ok" ] || fail "expected loglevel to be 'ok', got: $loglevel"

echo "PASS: all '--batch' mode test cases succeeded"

cleanup_tmpdir