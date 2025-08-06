# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe prepare test
    apt remove nftables -y

    describe Running failed test
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Running resolved
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    apt remove nftables -y
    apt autoremove -y
}
