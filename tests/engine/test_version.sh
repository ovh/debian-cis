#!/bin/bash
# run-shellcheck
set -e
set -u

source tests/engine/lib.sh

write_test_script test_script_1 1.1.1 1
write_test_script test_script_2 1.1.2 2

test_version=debian_12

mkdir -p "$WORK_DIR/versions/$test_version"
ln -s "$WORK_DIR/bin/hardening/test_script_2.sh" "$WORK_DIR/versions/$test_version/1.1.2_test_script_2.sh"

"$REPO_ROOT/bin/hardening.sh" --audit --allow-unsupported-distribution --set-version debian_12 >/dev/null
assert_not_exists "$CONF_D_DIR/1.1.1_test_script_1.cfg"
assert_file_exists "$CONF_D_DIR/1.1.2_test_script_2.cfg"

echo "PASS: all '--set-version' tests cases succeeded"

cleanup_tmpdir
