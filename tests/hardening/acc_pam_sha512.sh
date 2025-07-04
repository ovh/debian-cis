# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    register_test contain "is present in /etc/pam.d/common-password"
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests purposely failing
    sed -i '/pam_unix.so/ s/sha512/sha256/' "/etc/pam.d/common-password"   # Debian 10
    sed -i '/pam_unix.so/ s/yescrypt/sha256/' "/etc/pam.d/common-password" # Debian 11+
    register_test retvalshouldbe 1
    register_test contain "is not present"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "is present in /etc/pam.d/common-password"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

}
