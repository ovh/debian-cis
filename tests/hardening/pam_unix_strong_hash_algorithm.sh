# shellcheck shell=bash
# run-shellcheck
test_audit() {

    describe "Prepare on purpose failed test - remove strong hash from common-password"

    # Backup original config
    if [ -f /etc/pam.d/common-password ]; then
        cp /etc/pam.d/common-password /etc/pam.d/common-password.bak
    fi

    # Remove sha512/yescrypt from common-password to create non-compliant state if present
    if [ -f /etc/pam.d/common-password ]; then
        sed -Ei '/^[[:space:]]*password[[:space:]]+.*pam_unix\.so/ s/([[:space:]])(md5|bigcrypt|sha256|sha512|blowfish|gost_yescrypt|yescrypt)([[:space:]]|$)/\1/g' /etc/pam.d/common-password || true
    fi

    describe "Running on purpose failed test - no strong hash configured"
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Correcting situation - enabling remediation"
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe "Checking resolved state - strong hash should be configured"
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Restore original common-password"
    if [ -f /etc/pam.d/common-password.bak ]; then
        mv /etc/pam.d/common-password.bak /etc/pam.d/common-password
        # Re-run pam-auth-update to restore original state
        pam-auth-update --enable unix >/dev/null 2>&1 || true
    fi

}
