# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe set up failed check
    apt remove -y ufw iptables-persistent

    describe Running failed test
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe set up failed resolution
    DEBIAN_FRONTEND='noninteractive' apt -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install iptables-persistent apt-utils -y
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"

    describe running failed resolution
    # shellcheck disable=2154
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe running failed run after apply
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe fix resolution
    apt remove -y iptables-persistent

    describe running successfull resolution
    # shellcheck disable=2154
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe running successfull audit
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run success "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    apt remove -y ufw
    apt autoremove -y
}
