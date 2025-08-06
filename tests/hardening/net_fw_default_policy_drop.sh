# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # Do not run any check, iptables do not work in a docker
    #run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
    # TODO fill comprehensive tests
}
