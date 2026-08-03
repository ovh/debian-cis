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

    local audit_rules_file="/etc/audit/rules.d/50-usermod.rules"
    # shellcheck disable=2154
    local audit_rules_backup="/tmp/${script}.50-usermod.rules.bak"
    local login_defs_backup="/tmp/${script}.login.defs.bak"

    if [ -f "$audit_rules_file" ]; then
        cp "$audit_rules_file" "$audit_rules_backup"
    fi
    cp /etc/login.defs "$login_defs_backup"

    describe Test case: UID_MIN absent
    sed -i '/^UID_MIN/d' /etc/login.defs
    rm -f "$audit_rules_file"
    register_test retvalshouldbe 1
    register_test contain "UID_MIN"
    # shellcheck disable=2154
    run uid_min_absent "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
    cp "$login_defs_backup" /etc/login.defs

    describe Test case: audit rules file absent
    rm -f "$audit_rules_file"
    register_test retvalshouldbe 1
    register_test contain "not configured"
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Test case: broken/incomplete on-disk rule
    echo "-a always,exit -F path=/usr/sbin/usermod" >"$audit_rules_file"
    register_test retvalshouldbe 1
    register_test contain "not configured"
    # shellcheck disable=2154
    run broken_ondisk "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Test case: rules on disk but not loaded in runtime
    UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
    echo "-a always,exit -F path=/usr/sbin/usermod -F perm=x -F auid>=${UID_MIN} -F auid!=unset -k usermod" >"$audit_rules_file"
    auditctl -W /usr/sbin/usermod 2>/dev/null || true
    auditctl -D 2>/dev/null || true
    register_test retvalshouldbe 1
    register_test contain "running configuration"
    # shellcheck disable=2154
    run not_loaded_runtime "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    # shellcheck disable=2154
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "properly configured"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    rm -f "$audit_rules_file"
    if [ -f "$audit_rules_backup" ]; then
        mv "$audit_rules_backup" "$audit_rules_file"
    fi
    cp "$login_defs_backup" /etc/login.defs
    rm -f "$login_defs_backup"
}
