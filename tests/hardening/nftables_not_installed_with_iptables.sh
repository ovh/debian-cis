# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe set up successful check
    apt install -y iptables nftables

    describe Running failed test
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Fixing first situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe running success check
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run success "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    apt remove -y iptables
    apt autoremove -y

}
