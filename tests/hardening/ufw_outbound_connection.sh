# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe prepare test
    apt install -y ufw

    # default case: we want the outbound all rule to be present, but it is not
    describe Running on blank host
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # we can not apply the fix, unless running on a privileged container
    # we manually update the rules file
    describe fix the situation
    # shellcheck disable=2129
    echo '-A ufw-user-output -o all -j ACCEPT' >>/etc/ufw/user.rules

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # reverse case: we don't want the outbound all rule to be present, but it is
    describe prepare failed test
    sed -i '/ALLOW_OUTBOUND_ALL/s/=.*/=1/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"

    describe Running failed test
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe fix the situation
    # shellcheck disable=2129
    sed -i '$d' /etc/ufw/user.rules

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    apt purge -y ufw
    apt autoremove -y
}
