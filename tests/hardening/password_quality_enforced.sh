# shellcheck shell=bash
# run-shellcheck
test_audit() {

    # prepare to fail
    describe Prepare on purpose failed test
    apt-get install -y libpam-pwquality
    sed -E -i '/^[[:space:]]?enforcing/d' /etc/security/pwquality.conf
    echo "enforcing = 0" >>/etc/security/pwquality.conf
    echo "pam_pwquality.so enforcing=0" >/usr/share/pam-configs/test_cis.conf

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
    rm -f /usr/share/pam-configs/test_cis.conf
    apt-get remove -y libpam-pwquality

}
