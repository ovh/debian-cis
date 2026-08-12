#!/bin/bash
# run-shellcheck
set -e
set -u

source tests/engine/lib.sh

write_test_script 
sed -i '/audit()/s|:;|echo $LOGLEVEL > "'$WORK_DIR'/tmp/loglevel.txt" ;|' "$WORK_DIR/bin/hardening/$DEFAULT_SCRIPT_NAME.sh"

# need to shutdown test scripts output to avoid polluting the script json output
"$REPO_ROOT/bin/hardening.sh" --allow-unsupported-distribution --audit --summary-json  | grep 'available_checks' > "$WORK_DIR/tmp/summary.json"

assert_file_exists "$WORK_DIR/tmp/loglevel.txt"
loglevel=$(cat "$WORK_DIR/tmp/loglevel.txt")
[ "$loglevel" = "silent" ] || fail "expected loglevel to be 'silent', got: $loglevel"

assert_file_exists "$WORK_DIR/tmp/summary.json"

jq_bin=$(which jq) || true
if [ -z "$jq_bin" ]; then
    echo "WARNING: 'jq' not found, skipping summary.json content validation"
else
    "$jq_bin" . "$WORK_DIR/tmp/summary.json" > /dev/null || fail "summary.json is not valid JSON"
fi

echo "PASS: all '--summary-json' test cases succeeded"

cleanup_tmpdir