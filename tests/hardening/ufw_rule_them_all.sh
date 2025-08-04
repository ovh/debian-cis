# shellcheck shell=bash
# run-shellcheck
test_audit() {
    # no much to test here, unless running on a privileged container, to run ufw commands
    describe Running on blank host
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
}
