# shellcheck shell=bash
# run-shellcheck
test_audit() {
    local test_install_package=1
    if ! dpkg -s auditd 2>/dev/null | grep -q '^Status: install '; then
        apt install -y auditd
        test_install_package=0
    fi

    describe prepare failing test
    if [ -e /etc/audit/auditd.conf ]; then
        mv /etc/audit/auditd.conf /etc/audit/auditd.conf.save
    fi
    echo 'log_file=/var/tmp/audit_log_root_owned/foo.log' >/etc/audit/auditd.conf
    install -d -m 0777 /var/tmp/audit_log_root_owned

    describe Checking failed state
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    if [ -e /etc/audit/auditd.conf.save ]; then
        mv /etc/audit/auditd.conf.save /etc/audit/auditd.conf
    fi
    rm -rf /var/tmp/audit_log_root_owned

    if [ "$test_install_package" -eq 0 ]; then
        apt remove -y auditd
    fi
}
