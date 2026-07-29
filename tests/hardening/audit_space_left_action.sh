# shellcheck shell=bash
# run-shellcheck
test_audit() {
    if [ "$(id -u)" -ne 0 ]; then
        skip "SKIPPED: root required to edit auditd configuration"
        return
    fi

    local auditd_conf="/etc/audit/auditd.conf"
    # shellcheck disable=2154
    local auditd_conf_backup="/tmp/${script}.auditd.conf.bak"

    if [ ! -f "$auditd_conf" ]; then
        skip "SKIPPED: /etc/audit/auditd.conf not present"
        return
    fi

    cp "$auditd_conf" "$auditd_conf_backup"

    describe Test case: missing target configuration
    sed -i '/^\s*space_left_action\s*=/d' "$auditd_conf"
    sed -i '/^\s*admin_space_left_action\s*=/d' "$auditd_conf"
    register_test retvalshouldbe 1
    register_test contain "instead of"
    # shellcheck disable=2154
    run missing_keys "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Test case: broken/incomplete configuration
    sed -i '/^\s*space_left_action\s*=/d' "$auditd_conf"
    sed -i '/^\s*admin_space_left_action\s*=/d' "$auditd_conf"
    echo "space_left_action = ignore" >>"$auditd_conf"
    echo "admin_space_left_action = ignore" >>"$auditd_conf"
    register_test retvalshouldbe 1
    register_test contain "instead of"
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "space_left_action is set to email"
    register_test contain "admin_space_left_action is set to single"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Restore original configuration
    if [ -f "$auditd_conf_backup" ]; then
        mv "$auditd_conf_backup" "$auditd_conf"
        service auditd restart || true
    fi
}
