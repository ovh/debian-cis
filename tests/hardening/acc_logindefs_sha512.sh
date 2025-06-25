# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    register_test contain "is present in /etc/login.defs"
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    cp /etc/login.defs /tmp/login.defs.bak
    describe Line as comment
    sed -i 's/\(ENCRYPT_METHOD SHA512\)/# \1/' /etc/login.defs
    register_test retvalshouldbe 1
    register_test contain "is not present in /etc/login.defs"
    run commented "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    rm /etc/login.defs
    describe Fail: missing conf file
    register_test retvalshouldbe 1
    register_test contain "/etc/login.defs is not readable"
    run missconffile "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    cp /tmp/login.defs.bak /etc/login.defs
    sed -ir 's/ENCRYPT_METHOD[[:space:]]\+SHA512/ENCRYPT_METHOD MD5/' /etc/login.defs
    describe Fail: wrong hash function configuration
    register_test retvalshouldbe 1
    register_test contain "is not present in /etc/login.defs"
    run wrongconf "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "is present in /etc/login.defs"
    run sha512pass "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # DEB_MAJ_VER cannot be overwritten here;
    # therefore we need to trick get_debian_major_version
    ORIGINAL_DEB_VER="$(cat /etc/debian_version)"
    echo "sid" >/etc/debian_version

    describe Running on blank host as sid
    register_test retvalshouldbe 0
    register_test contain "(SHA512|yescrypt|YESCRYPT)"
    # shellcheck disable=2154
    run blanksid "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    cp /etc/login.defs /tmp/login.defs.bak
    sed -ir 's/ENCRYPT_METHOD[[:space:]]\+.*/ENCRYPT_METHOD MD5/' /etc/login.defs

    describe Fail: wrong hash function configuration as sid
    register_test retvalshouldbe 1
    register_test contain "(SHA512|yescrypt|YESCRYPT)"
    run wrongconfsid "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation as sid
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state as sid
    register_test retvalshouldbe 0
    register_test contain "(SHA512|yescrypt|YESCRYPT)"
    run sha512passsid "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    echo -n "$ORIGINAL_DEB_VER" >/etc/debian_version
    unset ORIGINAL_DEB_VER
}
