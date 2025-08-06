# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    echo "maxsessions 1" >>/etc/ssh/sshd_config

    describe Running restrictive
    register_test retvalshouldbe 0
    register_test contain "[ OK ] 1 is lower than recommended 10"
    run restrictive "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # delete last line
    sed -i '$ d' /etc/ssh/sshd_config
    echo "maxsessions 15" >>/etc/ssh/sshd_config

    describe Running too permissive
    register_test retvalshouldbe 1
    register_test contain "[ KO ] 15 is higher than recommended 10"
    run permissive "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    # `apply` performs a service reload after each change in the config file
    # the service needs to be started for the reload to succeed
    service ssh start
    # if the audit script provides "apply" option, enable and run it
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "[ OK ] ^maxsessions[[:space:]]*10 is present in /etc/ssh/sshd_config"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}
