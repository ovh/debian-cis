#!/bin/bash
# run-shellcheck
set -e
set -u

source tests/engine/lib.sh

write_test_script test_script_1 1.1.1 1
write_test_script test_script_2 1.1.2 2
write_test_script test_script_3 1.1.3 3

"$REPO_ROOT/bin/hardening.sh" --audit --allow-unsupported-distribution >/dev/null
assert_file_exists "$CONF_D_DIR/1.1.1_test_script_1.cfg"
assert_file_exists "$CONF_D_DIR/1.1.2_test_script_2.cfg"
assert_file_exists "$CONF_D_DIR/1.1.3_test_script_3.cfg"

assert_status "$CONF_D_DIR/1.1.1_test_script_1.cfg" audit
assert_status "$CONF_D_DIR/1.1.2_test_script_2.cfg" audit
assert_status "$CONF_D_DIR/1.1.3_test_script_3.cfg" audit

sed --follow-symlinks -i "s/^status=.*/status=disabled/" "$CONF_D_DIR"/1.1.1_test_script_1.cfg

"$REPO_ROOT/bin/hardening.sh" --audit-all --allow-unsupported-distribution | grep 'Total Runned Checks' >"$WORK_DIR/tmp/audit_summary.txt"

# audit-all will run even on disabled scripts
assert_status "$CONF_D_DIR/1.1.1_test_script_1.cfg" disabled
awk -F ':' '/Total Runned Checks/ {print $2}' "$WORK_DIR/tmp/audit_summary.txt" | grep -q '3' || fail "expected 3 runned checks, got: $(cat "$WORK_DIR/tmp/audit_summary.txt")"

echo "PASS: all '--audit-all' test cases succeeded"

cleanup_tmpdir
