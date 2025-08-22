# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe prepare test
    apt install -y ufw

    describe Running on blank host
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # we can not apply the fix, unless running on a privileged container
    # we manually update the rules file
    describe fix the situation
    # shellcheck disable=2129
    echo '-A ufw-user-input -i lo -j ACCEPT' >>/etc/ufw/user.rules
    echo '-A ufw-user-output -o lo -j ACCEPT' >>/etc/ufw/user.rules
    echo '-A ufw-user-input -s 127.0.0.0/8 -j DROP' >>/etc/ufw/user.rules
    echo '-A ufw-user-input -s ::1 -j DROP' >>/etc/ufw/user6.rules

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    apt purge -y ufw
    apt autoremove -y
}
