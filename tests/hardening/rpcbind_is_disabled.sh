# shellcheck shell=bash
# run-shellcheck
test_audit() {

    describe Prepare on purpose failed test
    apt install -y rpcbind
    # running on a container, will can only test the package installation, not the service management

    describe Running on purpose failed test
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Prepare test package dependencies
    # try to install a package that depends on 'rpcbind'
    apt install -y rstatd
    # running on a container, we can only test the package installation, not the service management

    describe Running successfull test
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean installation
    apt remove -y rpcbind rstatd
    apt autoremove -y

}
