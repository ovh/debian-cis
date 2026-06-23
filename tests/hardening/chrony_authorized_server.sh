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

    # Backup original configuration
    if [ -d /etc/chrony/sources.d ]; then
        cp -r /etc/chrony/sources.d /tmp/chrony_sources.d.backup
    fi

    describe Configure the check
    echo "CHRONY_TIME_SOURCES='pool time.example.com iburst maxsources 4'" >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"

    describe Tests purposely failing
    rm -rf /etc/chrony/sources.d/authorized.sources
    register_test retvalshouldbe 1
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "Time sources correctly configured"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    apt-get purge -y chrony || true
    rm -rf /etc/chrony/sources.d
    # Restore original configuration
    if [ -d /tmp/chrony_sources.d.backup ]; then
        mkdir -p /etc/chrony
        mv /tmp/chrony_sources.d.backup /etc/chrony/sources.d
    fi
}
