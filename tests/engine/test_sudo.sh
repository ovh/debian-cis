#!/bin/bash
# run-shellcheck
set -e
set -u

source tests/engine/lib.sh

write_test_script "$@"
# shellcheck disable=2016
# shellcheck disable=2086
sed -i '/audit()/s|:;|echo $SUDO_CMD > "'$WORK_DIR'/tmp/sudo_cmd.txt" ;|' "$WORK_DIR/bin/hardening/$DEFAULT_SCRIPT_NAME.sh"

"$REPO_ROOT/bin/hardening.sh" --allow-unsupported-distribution --audit --sudo >/dev/null

assert_file_exists "$WORK_DIR/tmp/sudo_cmd.txt"
sudo_cmd=$(cat "$WORK_DIR/tmp/sudo_cmd.txt")
[ "$sudo_cmd" = "sudo_wrapper" ] || fail "expected sudo command to be 'sudo_wrapper', got: $sudo_cmd"

# test without sudo
rm -f "$WORK_DIR/tmp/sudo_cmd.txt"
"$REPO_ROOT/bin/hardening.sh" --allow-unsupported-distribution --audit >/dev/null
assert_file_exists "$WORK_DIR/tmp/sudo_cmd.txt"
sudo_cmd=$(cat "$WORK_DIR/tmp/sudo_cmd.txt")
[ -z "$sudo_cmd" ] || fail "expected sudo command to be empty, got: $sudo_cmd"

echo "PASS: all '--sudo' test cases succeeded"

cleanup_tmpdir
