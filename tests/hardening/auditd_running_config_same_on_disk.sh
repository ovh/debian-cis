# shellcheck shell=bash
# run-shellcheck
test_audit() {
    local test_install_package=1
    if ! dpkg -s auditd 2>/dev/null | grep -q '^Status: install '; then
        apt install -y auditd
        test_install_package=0
    fi

    describe prepare failing test
    echo "-w /tmp/foo -p 777 -k test_rule" >/etc/audit/rules.d/test.rules

    describe Running failed
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    # shellcheck disable=2154
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    rm -f /etc/audit/rules.d/test.rules
    if [ "$test_install_package" -eq 0 ]; then
        apt remove -y auditd
    fi

}
