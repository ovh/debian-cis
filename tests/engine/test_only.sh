#!/bin/bash
# run-shellcheck
set -e
set -u

source tests/engine/lib.sh

write_test_script test_script_1 1.1.1 1
write_test_script test_script_2 1.1.2 2
write_test_script test_script_3 1.1.3 3

"$REPO_ROOT/bin/hardening.sh" --audit --allow-unsupported-distribution --only 1.1.1 > /dev/null
assert_file_exists "$CONF_D_DIR/1.1.1_test_script_1.cfg"
assert_not_exists "$CONF_D_DIR/1.1.2_test_script_2.cfg"
assert_not_exists "$CONF_D_DIR/1.1.3_test_script_3.cfg"

echo "PASS: all '--only' test cases succeeded"

cleanup_tmpdir