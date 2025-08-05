# shellcheck shell=bash
# run-shellcheck
test_audit() {

    apt install -y iptables netcat-traditional

    tests_is_ipv6_enabled
    tests_get_debian_major_version
    if [ "$CURRENT_IPV6_ENABLED" -eq 0 ] && [ "$DEB_MAJ_VER" -gt 11 ]; then

        describe Prepare test
        # shellcheck disable=2216
        timeout 5s nc -lp 404 | true &

        # not much to test here, unless working on a privileged container
        describe Running failed test
        register_test retvalshouldbe 1
        # shellcheck disable=2154
        run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

        describe correcting situation
        # just wait for timeout to expire
        sleep 5

    fi

    describe Running success
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run success "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe clean test
    apt remove -y iptables netcat-traditional

}
