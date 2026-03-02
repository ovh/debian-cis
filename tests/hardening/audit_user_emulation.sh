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

    local audit_rules_file="/etc/audit/rules.d/50-user_emulation.rules"
    # shellcheck disable=2154
    local audit_rules_backup="/tmp/${script}.50-user_emulation.rules.bak"

    if [ -f "$audit_rules_file" ]; then
        cp "$audit_rules_file" "$audit_rules_backup"
    fi

    describe Test case: audit rules file absent
    rm -f "$audit_rules_file"
    register_test retvalshouldbe 1
    register_test contain "not properly configured"
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Test case: broken/incomplete on-disk rules
    echo "-a always,exit -F arch=b64 -C euid!=uid -S execve -k user_emulation" >"$audit_rules_file"
    register_test retvalshouldbe 1
    register_test contain "not properly configured"
    # shellcheck disable=2154
    run broken_ondisk "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Test case: rules on disk but not loaded in runtime
    {
        echo "-a always,exit -F arch=b64 -C euid!=uid -F auid!=unset -S execve -k user_emulation"
        echo "-a always,exit -F arch=b32 -C euid!=uid -F auid!=unset -S execve -k user_emulation"
    } >"$audit_rules_file"
    auditctl -D 2>/dev/null || true
    register_test retvalshouldbe 1
    register_test contain "not properly loaded in running configuration"
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
}
