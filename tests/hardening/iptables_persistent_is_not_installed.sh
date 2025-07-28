# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe set up successful check
    apt remove -y ufw iptables-persistent

    describe Running success test
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run failure "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe set up failed check
    DEBIAN_FRONTEND='noninteractive' apt -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install iptables-persistent apt-utils -y

    describe running failed check
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run success "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    apt remove -y iptables-persistent
    apt autoremove -y

}
