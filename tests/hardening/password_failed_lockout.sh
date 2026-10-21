# shellcheck shell=bash
# run-shellcheck
test_audit() {

    local faillock_conf='/etc/security/faillock.conf'

    cp "$faillock_conf" /tmp/faillock.conf.bak

    describe Prepare on purpose failed test: deny not set
    sed -E -i '/^[[:space:]]*deny[[:space:]]*=/d' "$faillock_conf"
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noconf "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Prepare on purpose failed test: deny disabled
    echo "deny = 0" >>"$faillock_conf"
    register_test retvalshouldbe 1
    run disabled "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Checking a value lower than the maximum is compliant
    sed -E -i '/^[[:space:]]*deny[[:space:]]*=/d' "$faillock_conf"
    echo "deny = 3" >>"$faillock_conf"
    register_test retvalshouldbe 0
    run lower "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Prepare on purpose failed test: wrong value in /etc/pam.d
    printf '%s\n' 'auth requisite pam_faillock.so deny=6' >>/etc/pam.d/common-password
    register_test retvalshouldbe 1
    run pamd "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    mv /tmp/faillock.conf.bak "$faillock_conf"
    DEBIAN_FRONTEND='noninteractive' pam-auth-update --force

}
