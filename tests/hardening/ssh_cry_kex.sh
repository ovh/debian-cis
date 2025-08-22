# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 1
    register_test contain "openssh-server is installed"
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    # `apply` performs a service reload after each change in the config file
    # the service needs to be started for the reload to succeed
    service ssh start
    # if the audit script provides "apply" option, enable and run it
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    cp -a /etc/ssh/sshd_config /tmp/sshd_config.bak

    describe Change case of config line
    sed -i 's/\(KexAlgorithms\)/\U\1/' /etc/ssh/sshd_config
    register_test retvalshouldbe 0
    run uppercase "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    mv /tmp/sshd_config.bak /etc/ssh/sshd_config
    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
    describe Clean test
    pkill -9 sshd
}
