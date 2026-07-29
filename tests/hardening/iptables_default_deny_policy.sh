# shellcheck shell=bash
# run-shellcheck

is_running_in_container() {
    awk -F/ '$2 == "'"$1"'"' /proc/self/cgroup
}

test_audit() {
    if [ -n "$(is_running_in_container "docker")" ] ||
        [ -n "$(is_running_in_container "lxc")" ] ||
        [ -n "$(is_running_in_container "kubepods")" ]; then
        skip "SKIPPED on container: changing default iptables policy in a container can break networking for the test runtime/host and is not representative of a full host firewall setup"
        return
    fi

    describe Running audit
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Comprehensive non-compliant/apply tests are not executed to avoid firewall lockout.
}
