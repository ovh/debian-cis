# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    mkdir -p /etc/audit
    touch /etc/audit/auditd.conf
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    # to avoid error during auditd installation in 4.1.1.2, only necessary during tests
    sed -i "s/OPTIONS='/OPTIONS='space_left=100 admin_space_left=50 /" "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "[ OK ] ^space_left_action[[:space:]]*=[[:space:]]*email is present in /etc/audit/auditd.conf"
    register_test contain "[ OK ] ^action_mail_acct[[:space:]]*=[[:space:]]*root is present in /etc/audit/auditd.conf"
    register_test contain "[ OK ] ^admin_space_left_action[[:space:]]*=[[:space:]]*halt is present in /etc/audit/auditd.conf"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}
