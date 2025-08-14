# shellcheck shell=bash
# run-shellcheck
test_audit() {
    # at the time of writing, there is only one version of libpam-runtime available
    describe Checking on blank host
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

}
