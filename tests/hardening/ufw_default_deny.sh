# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe prepare test
    apt install -y ufw
    sed -i '/DEFAULT_INPUT_POLICY/s/=.*/="ACCEPT"/g' /etc/default/ufw

    describe Running on blank host
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # we can not apply the fix, unless running on a privileged container
    # we manually update the default file
    describe fix the situation
    sed -i '/DEFAULT_INPUT_POLICY/s/=.*/="DROP"/g' /etc/default/ufw
    sed -i '/DEFAULT_OUTPUT_POLICY/s/=.*/="DROP"/g' /etc/default/ufw
    sed -i '/DEFAULT_FORWARD_POLICY/s/=.*/="DROP"/g' /etc/default/ufw

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    apt purge -y ufw
    apt autoremove -y
}
