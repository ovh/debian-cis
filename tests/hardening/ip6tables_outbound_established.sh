# shellcheck shell=bash
# run-shellcheck

test_audit() {
    describe Prepare test
    apt install -y iptables

    tests_is_ipv6_enabled
    tests_get_debian_major_version
    if [ "$CURRENT_IPV6_ENABLED" -eq 0 ] && [ "$DEB_MAJ_VER" -gt 11 ]; then

        # not much to test here, unless working on a privileged container
        describe Running on blank host
        register_test retvalshouldbe 1
        # shellcheck disable=2154
        run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    else

        # not much to test here, unless working on a privileged container
        describe Running on blank host
        register_test retvalshouldbe 0
        # shellcheck disable=2154
        run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    fi

    describe clean test
    apt remove -y iptables

}
