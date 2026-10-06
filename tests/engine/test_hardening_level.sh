#!/bin/bash
# run-shellcheck
set -e
set -u

source tests/engine/lib.sh

write_test_script hardening_level_1 1.1.1 1
write_test_script hardening_level_2 1.1.2 2
write_test_script hardening_level_3 1.1.3 3

# --set-hardening-level enable requested level and below
"$REPO_ROOT/bin/hardening.sh" --set-hardening-level 2 --create-config-files-only --allow-unsupported-distribution
assert_file_exists "$CONF_D_DIR/1.1.1_hardening_level_1.cfg"
assert_file_exists "$CONF_D_DIR/1.1.2_hardening_level_2.cfg"
assert_file_exists "$CONF_D_DIR/1.1.3_hardening_level_3.cfg"

assert_status "$CONF_D_DIR/1.1.1_hardening_level_1.cfg" enabled
assert_status "$CONF_D_DIR/1.1.2_hardening_level_2.cfg" enabled
assert_status "$CONF_D_DIR/1.1.3_hardening_level_3.cfg" disabled

echo "PASS: all '--set-hardening-level'  test cases succeeded"

cleanup_tmpdir
