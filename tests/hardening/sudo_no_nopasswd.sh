# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    # we are providing a "NOPASSWD" sudoers for cis tests
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}
