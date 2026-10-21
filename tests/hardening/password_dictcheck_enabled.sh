# shellcheck shell=bash
# run-shellcheck
test_audit() {

    # prepare to fail
    describe Prepare on purpose failed test
    apt-get install -y libpam-pwquality
    sed -E -i '/^[[:space:]]?dictcheck/d' /etc/security/pwquality.conf
    printf '%s\n' 'password requisite pam_pwquality.so dictcheck=0' >>/etc/pam.d/common-password

    describe Running on purpose failed test
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -E -i 's/dictcheck[[:space:]]*=[[:space:]]*[0-9]+//g' /etc/pam.d/common-password
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    rm -f /usr/share/pam-configs/test_cis.conf
    apt-get remove -y libpam-pwquality

}
