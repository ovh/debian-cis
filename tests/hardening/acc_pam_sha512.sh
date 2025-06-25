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
    run solvedsid "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # DEB_MAJ_VER cannot be overwritten here;
    # therefore we need to trick get_debian_major_version
    ORIGINAL_DEB_VER="$(cat /etc/debian_version)"
    echo "sid" >/etc/debian_version

    describe Running on blank host as sid
    register_test retvalshouldbe 0
    register_test contain "(sha512|yescrypt)"
    run blanksid "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Tests purposely failing as sid
    sed -i '/pam_unix.so/ s/sha512/sha256/' "/etc/pam.d/common-password"   # Debian 10
    sed -i '/pam_unix.so/ s/yescrypt/sha256/' "/etc/pam.d/common-password" # Debian 11+
    register_test retvalshouldbe 1
    register_test contain "is not present"
    run noncompliantsid "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation as sid
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state as sid
    register_test retvalshouldbe 0
    register_test contain "is present in /etc/pam.d/common-password"
    run solvedsid "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    echo -n "$ORIGINAL_DEB_VER" >/etc/debian_version
    unset ORIGINAL_DEB_VER
}
