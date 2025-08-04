# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Prepare test
    apt install -y nftables

    # not much to test here, unless working on a privileged container
    describe Running on blank host
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    apt remove -y nftables

}
