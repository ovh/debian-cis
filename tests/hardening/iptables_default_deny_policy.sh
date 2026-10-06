# shellcheck shell=bash
# run-shellcheck

is_running_in_container() {
    awk -F/ '$2 == "'"$1"'"' /proc/self/cgroup
}

test_audit() {
    # shellcheck disable=2154
    local cfg_file="${CIS_CONF_DIR}/conf.d/${script}.cfg"
    local cfg_backup="/tmp/${script}.cfg.backup"
    local exception_chains=""
    local chain=""
    local policy=""

    if [ -f "$cfg_file" ]; then
        cp "$cfg_file" "$cfg_backup"
        rm -f "$cfg_file"
    fi

    describe Creating config file
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run create_config "${CIS_CHECKS_DIR}/${script}.sh" --create-config-files-only

    if ! grep -q '^IPT_ACCEPT_EXCEPTIONS=""$' "$cfg_file"; then
        fatal "Missing IPT_ACCEPT_EXCEPTIONS in generated config"
    fi

    describe Setting custom OUTPUT exception in config
    sed -i 's/^IPT_ACCEPT_EXCEPTIONS=.*/IPT_ACCEPT_EXCEPTIONS="OUTPUT"/' "$cfg_file"

    if [ -n "$(is_running_in_container "docker")" ] ||
        [ -n "$(is_running_in_container "lxc")" ] ||
        [ -n "$(is_running_in_container "kubepods")" ]; then
        if [ -f "$cfg_backup" ]; then
            cp "$cfg_backup" "$cfg_file"
            rm -f "$cfg_backup"
        else
            rm -f "$cfg_file"
        fi
        skip "SKIPPED on container: changing default iptables policy in a container can break networking for the test runtime/host and is not representative of a full host firewall setup"
        return
    fi

    describe Running audit
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    if ! dpkg -s iptables >/dev/null 2>&1; then
        if [ -f "$cfg_backup" ]; then
            cp "$cfg_backup" "$cfg_file"
            rm -f "$cfg_backup"
        else
            rm -f "$cfg_file"
        fi
        return
    fi

    for chain in INPUT OUTPUT FORWARD; do
        policy=$(iptables -S "$chain" 2>/dev/null | awk '/^-P/ {print $3}')
        if [ -n "$policy" ] && [ "$policy" != "DROP" ] && [ "$policy" != "REJECT" ]; then
            exception_chains="$exception_chains $chain"
        fi
    done

    if [ -n "$exception_chains" ]; then
        describe Running audit with configured exceptions
        sed -i "s/^IPT_ACCEPT_EXCEPTIONS=.*/IPT_ACCEPT_EXCEPTIONS=\"${exception_chains# }\"/" "$cfg_file"
        register_test retvalshouldbe 0
        register_test contain "allowed by configuration"
        run with_exceptions "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
    fi

    # Comprehensive non-compliant/apply tests are not executed to avoid firewall lockout.

    if [ -f "$cfg_backup" ]; then
        cp "$cfg_backup" "$cfg_file"
        rm -f "$cfg_backup"
    else
        rm -f "$cfg_file"
    fi
}
