# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    # `apply` performs a service reload after each change in the config file
    # the service needs to be started for the reload to succeed
    service ssh start
    # if the audit script provides "apply" option, enable and run it
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    echo "OPTIONS='LogLevel=DEBUG'" >>"${CIS_CONF_DIR}/conf.d/${script}.cfg"
    sed -i 's/LogLevel VERBOSE/LogLevel DEBUG/' /etc/ssh/sshd_config

    describe Checking custom conf
    register_test retvalshouldbe 0
    run customconf "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}
