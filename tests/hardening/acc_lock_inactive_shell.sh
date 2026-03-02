# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Tests purposely failing
    # Create a test user with invalid shell and unlocked password
    useradd -s /usr/sbin/nologin -M testuser_nologin || true
    passwd -u testuser_nologin || true
    register_test retvalshouldbe 1
    register_test contain "not locked"
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "properly locked"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    userdel -f testuser_nologin 2>/dev/null || true
}
