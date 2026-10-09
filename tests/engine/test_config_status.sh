#!/bin/bash
# run-shellcheck
set -eu
source tests/engine/lib.sh
trap cleanup_tmpdir EXIT
write_test_script "$@"
"$WORK_DIR/bin/hardening/$DEFAULT_SCRIPT_NAME.sh" --create-config-files-only >/dev/null
printf 'status=misspelled\n' >"$CONF_D_DIR/$DEFAULT_SCRIPT_NAME.cfg"
status=0
"$WORK_DIR/bin/hardening/$DEFAULT_SCRIPT_NAME.sh" --audit >"$WORK_DIR/tmp/output" 2>&1 || status=$?
[ "$status" = 1 ] || fail 'invalid status reported a passing check'
echo 'PASS: invalid configuration status cannot report success'
