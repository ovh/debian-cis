# shellcheck shell=bash
# run-shellcheck
test_audit() {
    # shellcheck disable=2154
    "${CIS_CHECKS_DIR}/${script}.sh" --create-config-files-only

    tests_is_ipv6_enabled
    if [ "$CURRENT_IPV6_ENABLED" -eq 0 ]; then
        describe prepare failing test
        # shellcheck disable=2154
        sed -i '/^IPV6_ENABLED/s/=.*$/=1/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"

        describe Running failed test
        register_test retvalshouldbe 1
        # shellcheck disable=2154
        run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

        describe fix situation
        # shellcheck disable=2154
        sed -i '/^IPV6_ENABLED/s/=.*$/=0/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"

        describe Running successful test
        register_test retvalshouldbe 0
        # shellcheck disable=2154
        run success "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    else
        describe prepare failing test
        # shellcheck disable=2154
        sed -i '/^IPV6_ENABLED/s/=.*$/=0/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"

        describe Running failed test
        register_test retvalshouldbe 1
        # shellcheck disable=2154
        run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

        describe fix situation
        sed -i '/^IPV6_ENABLED/s/=.*$/=1/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"

        describe Running successful test
        register_test retvalshouldbe 0
        # shellcheck disable=2154
        run success "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    fi

}
