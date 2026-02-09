# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Test without chrony installed
    apt-get purge -y chrony || true
    register_test retvalshouldbe 1
    register_test contain "not installed"
    # shellcheck disable=2154
    run no_chrony "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Installing chrony
    apt-get install -y chrony || true

    describe Configure the check
    echo "CHRONY_TIME_SOURCES='pool time.example.com iburst maxsources 4'" >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"

    describe Tests purposely failing
    rm -rf /etc/chrony/sources.d/authorized.sources
    register_test retvalshouldbe 1
    register_test contain "does not exist"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "correctly configured"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    apt-get purge -y chrony || true
    rm -rf /etc/chrony/sources.d
}
