# shellcheck shell=bash
# run-shellcheck
test_audit() {

    # prepare to fail
    describe Prepare on purpose failed test
    apt-get install -y libpam-pwquality
    sed -E -i '/^[[:space:]]?enforce_for_root/d' /etc/security/pwquality.conf
    printf '%s\n' 'password requisite pam_pwquality.so enforce_for_root' >>/etc/pam.d/common-password

    describe Running on purpose failed test
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -E -i 's/enforce_for_root//g' /etc/pam.d/common-password
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    apt-get remove -y libpam-pwquality

}
