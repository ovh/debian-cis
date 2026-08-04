# shellcheck shell=bash
# run-shellcheck
test_audit() {

    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Installing openssh-server for tests"
    apt-get update >/dev/null 2>&1 || true
    apt-get install -y openssh-server >/dev/null 2>&1 || {
        skip "Cannot install openssh-server, skipping tests"
        return
    }

    describe Correcting situation
    # `apply` performs a service reload after each change in the config file
    # the service needs to be started for the reload to succeed
    describe "Starting ssh service"
    service ssh start || systemctl start ssh || true
    # if the audit script provides "apply" option, enable and run it
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "[ OK ] ^Protocol[[:space:]]*2 is present in /etc/ssh/sshd_config"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Clean test - stop sshd"
    pkill -9 sshd || true
    sleep 1

    describe "Remove openssh-server"
    apt-get remove -y openssh-server >/dev/null 2>&1 || true
    apt-get autoremove -y >/dev/null 2>&1 || true
}
