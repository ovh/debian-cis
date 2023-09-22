# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 1
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    apt-get update
    apt-get install -y iptables

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "provides firewalling feature"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

}
