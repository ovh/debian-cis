# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Prepare test
    apt remove -y gdm3

    describe Running resolved test
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

}
