#!/bin/bash
# run-shellcheck
set -eu
source tests/engine/lib.sh
trap cleanup_tmpdir EXIT
write_test_script "$@"
errors=0
reject() {
    local status=0
    "$REPO_ROOT/bin/hardening.sh" "$@" >"$WORK_DIR/tmp/output" 2>&1 || status=$?
    if [ "$status" != 2 ]; then
        echo "FAIL: $* returned $status rather than a usage error" >&2
        errors=$((errors + 1))
    fi
}
reject --audit --apply
reject --audit --only
reject --audit --set-version
reject --audit --set-log-level
reject --audit --unknown-option
reject --audit --only 999.999
reject --audit --set-log-level invalid
reject --audit --only not-a-number
reject --apply --sudo
reject --audit-all-enable-passed --sudo
reject --audit --summary-json --batch
reject --audit --allow-service http
reject --audit --create-config-files-only
reject --audit --set-hardening-level 2
reject --set-hardening-level 0
reject --allow-service-list --audit
reject --allow-service-list --create-config-files-only
reject --allow-service-list --only 1.1.1
reject --apply --summary-json
reject --set-hardening-level 2 --batch
[ "$errors" = 0 ] || exit 1
assert_not_exists "$CONF_D_DIR/$DEFAULT_SCRIPT_NAME.cfg"
echo 'PASS: invalid requests fail before creating configuration or running checks'
