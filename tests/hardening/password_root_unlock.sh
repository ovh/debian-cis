# shellcheck shell=bash
# run-shellcheck
test_audit() {

    local faillock_conf='/etc/security/faillock.conf'

    cp "$faillock_conf" /tmp/faillock.conf.bak

    describe Prepare on purpose failed test: root lockout not configured
    sed -E -i '/^[[:space:]]*(root_unlock_time|even_deny_root)/d' "$faillock_conf"
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noconf "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Checking even_deny_root alone is compliant
    echo "even_deny_root" >>"$faillock_conf"
    register_test retvalshouldbe 0
    run even_deny_root "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Prepare on purpose failed test: root_unlock_time too low
    echo "root_unlock_time = 30" >>"$faillock_conf"
    register_test retvalshouldbe 1
    run conf_too_low "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved_conf "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Prepare on purpose failed test: wrong value in /etc/pam.d
    printf '%s\n' 'auth required pam_faillock.so root_unlock_time=30' >>/etc/pam.d/common-password
    register_test retvalshouldbe 1
    run pamd "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved_pamd "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    mv /tmp/faillock.conf.bak "$faillock_conf"
    DEBIAN_FRONTEND='noninteractive' pam-auth-update --force

}
