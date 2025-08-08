# shellcheck shell=bash
# run-shellcheck
is_ipv6_enabled() {

    CURRENT_IPV6_ENABLED=1
    if sysctl net.ipv6 >/dev/null 2>&1; then
        for iface in /proc/sys/net/ipv6/conf/*; do
            ifname=$(basename "$iface")
            if [ "$ifname" != "default" ] && [ "$ifname" != "all" ]; then
                value=$(cat "$iface"/disable_ipv6)
                # if only one interface has ipv6, this is enough to consider it enabled
                if [ "$value" -eq 0 ]; then
                    CURRENT_IPV6_ENABLED=0
                    break
                fi
            fi
        done
    fi
}

test_audit() {
    # shellcheck disable=2154
    "${CIS_CHECKS_DIR}/${script}.sh" --create-config-files-only

    is_ipv6_enabled
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
