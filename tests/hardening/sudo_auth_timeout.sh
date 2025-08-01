# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe prepare test
    echo "Defaults timestamp_timeout=15" >/etc/sudoers.d/test_1
    echo "Defaults timestamp_timeout=20" >/etc/sudoers.d/test_2

    # by default authentication should not be configured
    describe Running failed
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Fix the situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    # by default authentication should not be configured
    describe Running resolved
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    rm -f /etc/sudoers.d/test_1 /etc/sudoers.d/test_2

}
