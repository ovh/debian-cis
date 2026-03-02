# shellcheck shell=bash
# run-shellcheck
test_audit() {
    # Backup original auditd.conf
    if [ -f /etc/audit/auditd.conf ]; then
        cp /etc/audit/auditd.conf /tmp/auditd.conf.bak
    fi

    describe Tests purposely failing
    # Set incorrect values
    sed -i 's/^\s*space_left_action\s*=.*/space_left_action = ignore/' /etc/audit/auditd.conf
    sed -i 's/^\s*admin_space_left_action\s*=.*/admin_space_left_action = ignore/' /etc/audit/auditd.conf
    register_test retvalshouldbe 1
    register_test contain "instead of"
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "correctly configured"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Restore original configuration
    if [ -f /tmp/auditd.conf.bak ]; then
        mv /tmp/auditd.conf.bak /etc/audit/auditd.conf
        service auditd restart || true
    fi
}
