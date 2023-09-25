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
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "[ OK ] ^max_log_file_action[[:space:]]*=[[:space:]]*keep_logs is present in /etc/audit/auditd.conf"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}
