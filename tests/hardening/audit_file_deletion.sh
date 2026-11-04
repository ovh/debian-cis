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
    # shellcheck disable=2154
    local login_defs_backup="/tmp/${script}.login.defs.bak"
    # shellcheck disable=2154
    local script_cfg="${CIS_CONF_DIR}/conf.d/${script}.cfg"
    # shellcheck disable=2154
    local cfg_backup="/tmp/${script}.cfg.bak"
    local uid_min

    rm -f "$audit_rules_backup" "$cfg_backup"
    if [ -f "$audit_rules_file" ]; then
        cp "$audit_rules_file" "$audit_rules_backup"
    fi
    if [ -f "$script_cfg" ]; then
        cp "$script_cfg" "$cfg_backup"
    fi
    cp /etc/login.defs "$login_defs_backup"
    uid_min=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
    rm -f "$audit_rules_file"
    auditctl -D >/dev/null 2>&1 || true

    describe Test case: UID_MIN absent
    sed -i '/^\s*UID_MIN/d' /etc/login.defs
    register_test retvalshouldbe 1
    register_test contain "Unable to determine UID_MIN"
    # shellcheck disable=2154
    run uid_min_absent "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
    cp "$login_defs_backup" /etc/login.defs

    describe Test case: no rule loaded
    register_test retvalshouldbe 1
    register_test contain "not found or incomplete in running configuration (complete arch: none)"
    run rules_absent "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Test case: b64 rule only loaded
    auditctl -a always,exit -F arch=b64 -S rename,unlink,unlinkat,renameat -F "auid>=${uid_min}" -F auid!=unset -k delete
    register_test retvalshouldbe 1
    register_test contain "(complete arch: b64)"
    run b64_only "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
    auditctl -D >/dev/null 2>&1 || true

    describe Test case: renameat missing in loaded rules
    auditctl -a always,exit -F arch=b64 -S rename,unlink,unlinkat -F "auid>=${uid_min}" -F auid!=unset -k delete
    auditctl -a always,exit -F arch=b32 -S rename,unlink,unlinkat -F "auid>=${uid_min}" -F auid!=unset -k delete
    register_test retvalshouldbe 1
    register_test contain "(complete arch: none)"
    run missing_syscall "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
    auditctl -D >/dev/null 2>&1 || true

    describe Test case: wrong auid filter in loaded rules
    auditctl -a always,exit -F arch=b64 -S rename,unlink,unlinkat,renameat -F "auid>=${uid_min}0" -F auid!=unset -k delete
    auditctl -a always,exit -F arch=b32 -S rename,unlink,unlinkat,renameat -F "auid>=${uid_min}0" -F auid!=unset -k delete
    register_test retvalshouldbe 1
    run wrong_auid "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
    auditctl -D >/dev/null 2>&1 || true

    describe Test case: compliant rules loaded with separate -S options
    auditctl -a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F "auid>=${uid_min}" -F auid!=4294967295 -k delete
    auditctl -a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -F "auid>=${uid_min}" -F auid!=4294967295 -k delete
    register_test retvalshouldbe 0
    register_test contain "File deletion audit rules found in running configuration"
    run compliant_separate "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
    auditctl -D >/dev/null 2>&1 || true

    describe Correcting situation
    sed -i 's/audit/enabled/' "$script_cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "File deletion audit rules found in running configuration"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Restoring host state
    rm -f "$audit_rules_file"
    if [ -f "$audit_rules_backup" ]; then
        mv "$audit_rules_backup" "$audit_rules_file"
    fi
    if [ -f "$cfg_backup" ]; then
        mv "$cfg_backup" "$script_cfg"
    fi
    cp "$login_defs_backup" /etc/login.defs
    rm -f "$login_defs_backup"
    auditctl -D >/dev/null 2>&1 || true
    augenrules --load >/dev/null 2>&1 || true
}
