# shellcheck shell=bash
# run-shellcheck
test_audit() {
    cp /etc/login.defs /tmp/login.defs.bak

    describe "Compliant state - SHA512 or yescrypt configured"
    register_test retvalshouldbe 0
    register_test contain "ENCRYPT_METHOD is set to an approved algorithm"
    # shellcheck disable=2154
    run compliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Non-compliant: ENCRYPT_METHOD commented out"
    sed -i 's/^\(ENCRYPT_METHOD\)/# \1/' /etc/login.defs
    register_test retvalshouldbe 1
    register_test contain "ENCRYPT_METHOD is not set to an approved algorithm"
    run commented "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Non-compliant: ENCRYPT_METHOD set to MD5"
    cp /tmp/login.defs.bak /etc/login.defs
    sed -i 's/^ENCRYPT_METHOD[[:space:]]\+.*/ENCRYPT_METHOD MD5/' /etc/login.defs
    register_test retvalshouldbe 1
    register_test contain "ENCRYPT_METHOD is not set to an approved algorithm"
    run wrongconf "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Non-compliant: /etc/login.defs missing"
    rm /etc/login.defs
    register_test retvalshouldbe 1
    register_test contain "/etc/login.defs is not readable"
    run missconffile "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
    cp /tmp/login.defs.bak /etc/login.defs

    describe "Correcting situation - enabling remediation"
    sed -i 's/^ENCRYPT_METHOD[[:space:]]\+.*/ENCRYPT_METHOD MD5/' /etc/login.defs
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe "Checking resolved state"
    register_test retvalshouldbe 0
    register_test contain "ENCRYPT_METHOD is set to an approved algorithm"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    cp /tmp/login.defs.bak /etc/login.defs
}
