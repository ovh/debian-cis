# shellcheck shell=bash
# run-shellcheck
test_audit() {

    # not much to test here, we are running in a container, we wont check service state
    describe Checking blank host
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

}
