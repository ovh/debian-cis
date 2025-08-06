# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Prepare failing test
    apt remove -y auditd

    describe Running on blank host
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state
    # service still wont be enabled due to tests running inside a docker container
    register_test retvalshouldbe 1
    register_test contain "[ OK ] auditd is installed"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}
