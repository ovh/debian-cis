# shellcheck shell=bash
# run-shellcheck
test_audit() {

    # prepare to fail
    describe Prepare on purpose failed test
    apt-get install -y libpam-pwquality
    sed -E -i '/^[[:space:]]?difok/d' /etc/security/pwquality.conf
    printf '%s\n' 'password requisite pam_pwquality.so difok=1' >>/etc/pam.d/common-password

    describe Running on purpose failed test
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    rm -f /etc/pam.d/common-password
    apt-get remove -y libpam-pwquality

}
