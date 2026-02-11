# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Tests purposely failing
    rm -f /etc/audit/rules.d/50-perm_chng.rules
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    rm -f /etc/audit/rules.d/50-perm_chng.rules
}
