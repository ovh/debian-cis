# shellcheck shell=bash
# run-shellcheck
test_audit() {
    # Backup any existing pwhistory config files
    if ls /usr/share/pam-configs/pwhistory* 1>/dev/null 2>&1; then
        mkdir -p /tmp/pam_backup
        cp /usr/share/pam-configs/pwhistory* /tmp/pam_backup/ 2>/dev/null || true
    fi

    # Ensure pwhistory is enabled first
    if ! grep -q "pam_pwhistory.so" /usr/share/pam-configs/*; then
        arr=('Name: pwhistory password history checking' 'Default: yes' 'Priority: 1024' 'Password-Type: Primary' 'Password:' '   requisite pam_pwhistory.so remember=24')
        printf '%s\n' "${arr[@]}" >/usr/share/pam-configs/pwhistory
        DEBIAN_FRONTEND='noninteractive' pam-auth-update --force --enable pwhistory
    fi

    describe Tests purposely failing - missing enforce_for_root
    # Remove enforce_for_root if present
    sed -i 's/enforce_for_root//g' /usr/share/pam-configs/*
    DEBIAN_FRONTEND='noninteractive' pam-auth-update --force --enable pwhistory
    register_test retvalshouldbe 1
    register_test contain "not present"
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "is present"
    register_test contain "is active"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    rm -f /usr/share/pam-configs/pwhistory

    # Restore original config files if they existed
    if [ -d /tmp/pam_backup ] && ls /tmp/pam_backup/pwhistory* 1>/dev/null 2>&1; then
        cp /tmp/pam_backup/pwhistory* /usr/share/pam-configs/ 2>/dev/null || true
        rm -rf /tmp/pam_backup
    fi

    DEBIAN_FRONTEND='noninteractive' pam-auth-update --force
}
