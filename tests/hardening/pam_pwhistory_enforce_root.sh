# shellcheck shell=bash
# run-shellcheck
test_audit() {
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
    DEBIAN_FRONTEND='noninteractive' pam-auth-update --force
}
