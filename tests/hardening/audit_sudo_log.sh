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

    local audit_rules_file="/etc/audit/rules.d/50-sudo.rules"
    # shellcheck disable=2154
    local audit_rules_backup="/tmp/${script}.50-sudo.rules.bak"
    local sudoers_test_file="/etc/sudoers.d/cis_test_logfile"
    # shellcheck disable=2154
    local sudoers_test_backup="/tmp/${script}.cis_test_logfile.bak"
    # shellcheck disable=2154
    local script_cfg="${CIS_CONF_DIR}/conf.d/${script}.cfg"
    # shellcheck disable=2154
    local cfg_backup="/tmp/${script}.cfg.bak"
    local sudo_logfile="/var/log/sudo.log"

    rm -f "$audit_rules_backup" "$sudoers_test_backup" "$cfg_backup"
    if [ -f "$audit_rules_file" ]; then
        cp "$audit_rules_file" "$audit_rules_backup"
    fi
    if [ -f "$sudoers_test_file" ]; then
        cp "$sudoers_test_file" "$sudoers_test_backup"
    fi
    if [ -f "$script_cfg" ]; then
        cp "$script_cfg" "$cfg_backup"
    fi
    rm -f "$audit_rules_file"

    # Lines that must not be taken for a logfile setting
    cat >"$sudoers_test_file" <<'EOF'
root ALL=(root) NOPASSWD: /usr/lib/nagios/plugins/check_logfiles
# Defaults logfile="/var/log/commented.log"
EOF
    chmod 0440 "$sudoers_test_file"

    describe Test case: no logfile in sudoers, only check_logfiles and comments
    if grep -hPq -- '^\h*Defaults\b[^#]*\blogfile\h*=' /etc/sudoers /etc/sudoers.d/* 2>/dev/null; then
        skip "SKIPPED: a sudo logfile is already configured on this host"
    else
        # not applicable: missing sudo logfile is covered by logfile_sudo
        register_test retvalshouldbe 0
        register_test contain "No sudo logfile configured in sudoers"
        # shellcheck disable=2154
        run no_logfile "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
    fi

    echo "Defaults logfile=\"${sudo_logfile}\"" >>"$sudoers_test_file"

    describe Test case: audit rules file absent
    auditctl -D >/dev/null 2>&1 || true
    register_test retvalshouldbe 1
    register_test contain "Sudo log file ${sudo_logfile} audit rule not found in on-disk configuration"
    run rules_file_absent "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Test case: rule on disk missing attribute permission
    echo "-w ${sudo_logfile} -p w -k sudo_log_file" >"$audit_rules_file"
    register_test retvalshouldbe 1
    register_test contain "not found in on-disk configuration"
    run rule_missing_perm "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Test case: rule on disk for another path with the same prefix
    echo "-w ${sudo_logfile}.1 -p wa -k sudo_log_file" >"$audit_rules_file"
    register_test retvalshouldbe 1
    register_test contain "not found in on-disk configuration"
    run rule_wrong_path "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Test case: rule on disk but not loaded in running configuration
    echo "-w ${sudo_logfile} -p wa -k sudo_log_file" >"$audit_rules_file"
    auditctl -D >/dev/null 2>&1 || true
    register_test retvalshouldbe 1
    register_test contain "audit rule found in on-disk configuration"
    register_test contain "audit rule not found in running configuration"
    run rules_not_loaded "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation from broken rule
    echo "-w ${sudo_logfile} -p w -k sudo_log_file" >"$audit_rules_file"
    sed -i 's/audit/enabled/' "$script_cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Test case: rule loaded in running configuration but removed from disk
    rm -f "$audit_rules_file"
    register_test retvalshouldbe 1
    register_test contain "not found in on-disk configuration"
    register_test contain "audit rule found in running configuration"
    run rules_not_on_disk "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Restoring host state
    rm -f "$audit_rules_file" "$sudoers_test_file"
    if [ -f "$audit_rules_backup" ]; then
        mv "$audit_rules_backup" "$audit_rules_file"
    fi
    if [ -f "$sudoers_test_backup" ]; then
        mv "$sudoers_test_backup" "$sudoers_test_file"
    fi
    if [ -f "$cfg_backup" ]; then
        mv "$cfg_backup" "$script_cfg"
    fi
    auditctl -D >/dev/null 2>&1 || true
    augenrules --load >/dev/null 2>&1 || true
}
