# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    # chance to not have any souces list on a blank host are close to null
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}
