# shellcheck shell=bash
# run-shellcheck
test_audit() {

    describe Prepare on purpose failed test
    sed -i '/umask/d' /root/.bash_profile || true
    echo "umask 022" >>/root/.bash_profile

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

}
