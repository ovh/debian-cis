# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe prepare failing test disk_full
    apt install -y auditd
    sed -i -e '/disk_full_action/d' -e '/disk_error_action/d' /etc/audit/auditd.conf
    echo "disk_full_action = SUSPEND" >>/etc/audit/auditd.conf
    echo "disk_error_action = halt" >>/etc/audit/auditd.conf

    describe Running failed 'disk_full_action'
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    # shellcheck disable=2154
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe prepare failing test disk_error
    apt install -y auditd
    sed -i -e '/disk_full_action/d' -e '/disk_error_action/d' /etc/audit/auditd.conf
    echo "disk_full_action = halt" >>/etc/audit/auditd.conf
    echo "disk_error_action = suspend" >>/etc/audit/auditd.conf

    describe Running failed 'disk_error_action'
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    # shellcheck disable=2154
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    apt purge -y auditd
    apt autoremove -y

}
