# shellcheck shell=bash
# run-shellcheck
test_audit() {

    tests_get_debian_major_version
    if [ "$DEB_MAJ_VER" -gt 11 ]; then

        describe Prepare test
        apt install -y iptables

        # not much to test here, unless working on a privileged container
        describe Running on blank host
        register_test retvalshouldbe 1
        # shellcheck disable=2154
        run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

        describe clean test
        apt remove -y iptables

    fi

}
