# shellcheck shell=bash
# run-shellcheck
test_audit() {
    # it should be installed by default
    describe Checking blank host
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

}
