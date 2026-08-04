# shellcheck shell=bash
# run-shellcheck
test_audit() {
    if [ "$(id -u)" -ne 0 ]; then
        skip "SKIPPED: root required to manage users"
        return
    fi

    if getent passwd testuser_gid0 >/dev/null 2>&1; then
        skip "SKIPPED: test user testuser_gid0 already exists"
        return
    fi

    describe Create non-compliant state
    useradd -o -u 19999 -g 0 -M -s /usr/sbin/nologin testuser_gid0
    register_test retvalshouldbe 1
    register_test contain "non-root accounts have primary GID 0"
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Perform documented manual remediation
    userdel -f testuser_gid0 2>/dev/null || true

    describe Re-audit compliant state
    register_test retvalshouldbe 0
    register_test contain "No non-root account has primary GID 0"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}
