# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Setup sudo log file
    echo "Defaults logfile=\"/var/log/sudo.log\"" >/etc/sudoers.d/cis_test_logfile

    describe Tests purposely failing
    rm -f /etc/audit/rules.d/50-sudo.rules
    register_test retvalshouldbe 1
    register_test contain "does not exist"
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "is audited"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    rm -f /etc/audit/rules.d/50-sudo.rules /etc/sudoers.d/cis_test_logfile
}
