# shellcheck shell=bash
# run-shellcheck
test_audit() {
    # running on a container, not much to test here
    describe Running on blank host
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

}
