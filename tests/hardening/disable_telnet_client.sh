# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Installing telnet for tests
    apt-get update >/dev/null 2>&1 || true
    DEBIAN_FRONTEND='noninteractive' apt-get install -y telnet >/dev/null 2>&1 || {
        skip "Cannot install telnet, skipping tests"
        return
    }

    describe Create non-compliant state
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Re-audit compliant state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Cleanup
    apt-get purge -y telnet >/dev/null 2>&1 || true
    apt-get autoremove -y >/dev/null 2>&1 || true
}
