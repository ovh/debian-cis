# shellcheck shell=bash
# run-shellcheck
test_audit() {
    if [ "$(id -u)" -ne 0 ]; then
        skip "SKIPPED: root required for audit runtime tests"
        return
    fi

    # auditctl runtime access requires kernel audit capabilities (for example CAP_AUDIT_CONTROL),
    # which may be unavailable in some environments (containers, restricted CI, hardened hosts).
    if ! command -v auditctl >/dev/null 2>&1 || ! auditctl -s >/dev/null 2>&1; then
        skip "SKIPPED: audit runtime not available"
        return
    fi

    local audit_rules_file="/etc/audit/rules.d/50-delete.rules"
    # shellcheck disable=2154
    local audit_rules_backup="/tmp/${script}.50-delete.rules.bak"
    local login_defs_backup="/tmp/${script}.login.defs.bak"

    if [ -f "$audit_rules_file" ]; then
        cp "$audit_rules_file" "$audit_rules_backup"
    fi
    cp /etc/login.defs "$login_defs_backup"

    # Test 1: UID_MIN missing from /etc/login.defs
    describe Test case: UID_MIN absent
    sed -i '/^UID_MIN/d' /etc/login.defs
    rm -f "$audit_rules_file"
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run uid_min_absent "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
    # Restore for next test
    cp "$login_defs_backup" /etc/login.defs

    # Test 2: Rules file missing (on-disk config absent)
    describe Test case: audit rules file absent
    rm -f "$audit_rules_file"
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run rules_file_absent "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Test 3: Rules on disk but incomplete/broken
    describe Test case: broken/incomplete audit rule on disk
    echo "-a always,exit -F perm=x" >"$audit_rules_file"
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run rules_incomplete "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Test 4: Rules on disk but not yet loaded in runtime
    describe Test case: rules on disk but not in running config
    # Create valid rule on disk
    # shellcheck disable=2154
    UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
    echo "-a always,exit -F path=/usr/bin/unlink -F auid>=${UID_MIN} -F auid!=unset -k delete" >"$audit_rules_file"
    # Remove from runtime
    auditctl -W /usr/bin/unlink 2>/dev/null || true
    auditctl -D 2>/dev/null || true
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run rules_not_loaded "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Test 5: Apply fix and verify compliance
    describe Correcting situation
    # shellcheck disable=2154
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    rm -f "$audit_rules_file"
    if [ -f "$audit_rules_backup" ]; then
        mv "$audit_rules_backup" "$audit_rules_file"
    fi
    cp "$login_defs_backup" /etc/login.defs
    rm -f "$login_defs_backup"
}
