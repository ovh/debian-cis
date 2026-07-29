# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Test without systemd-timesyncd installed
    apt-get purge -y systemd-timesyncd || true
    register_test retvalshouldbe 1
    register_test contain "not installed"
    # shellcheck disable=2154
    run no_timesyncd "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Installing systemd-timesyncd
    apt-get install -y systemd-timesyncd || true

    # Backup original configuration
    if [ -d /etc/systemd/timesyncd.conf.d ]; then
        cp -r /etc/systemd/timesyncd.conf.d /tmp/timesyncd.conf.d.backup
    fi

    describe Configure the check
    echo "NTP_SERVERS='time.example.com'" >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    echo "FALLBACK_NTP_SERVERS='pool.ntp.org'" >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"

    describe Tests purposely failing
    rm -rf /etc/systemd/timesyncd.conf.d/50-timesyncd.conf
    register_test retvalshouldbe 1
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "Timesyncd is properly configured"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    rm -rf /etc/systemd/timesyncd.conf.d
    # Restore original configuration
    if [ -d /tmp/timesyncd.conf.d.backup ]; then
        mkdir -p /etc/systemd
        mv /tmp/timesyncd.conf.d.backup /etc/systemd/timesyncd.conf.d
    fi
}
