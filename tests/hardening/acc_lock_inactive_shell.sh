# shellcheck shell=bash
# run-shellcheck
test_audit() {
    if [ "$(id -u)" -ne 0 ]; then
        skip "SKIPPED: root required to manage users"
        return
    fi

    if getent passwd testuser_nologin >/dev/null 2>&1; then
        skip "SKIPPED: test user testuser_nologin already exists"
        return
    fi

    describe Create non-compliant state
    # Create test user with nologin shell and an unlocked password state.
    useradd -s /usr/sbin/nologin -M testuser_nologin
    passwd -d testuser_nologin || true
    register_test retvalshouldbe 1
    register_test contain "not locked"
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    # shellcheck disable=2154
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Re-audit compliant state
    register_test retvalshouldbe 0
    register_test contain "All accounts without valid login shells are locked"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Restore/cleanup
    userdel -f testuser_nologin 2>/dev/null || true
}
