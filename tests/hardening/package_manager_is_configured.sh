# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe prepare failing test
    # we'll have to bring back the sources after the test
    find /etc/apt -name '*.list' -exec cat {} \; -exec rm -f {} \; >>/tmp/sources.list
    find /etc/apt -name '*.sources' -exec cat {} \; -exec rm -f {} \; >>/tmp/sources.sources

    describe Running failed test
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe fix situation
    if [ -s /tmp/sources.list ]; then
        mv /tmp/sources.list /etc/apt/
    fi

    if [ -s /tmp/sources.sources ]; then
        mv /tmp/sources.sources /etc/apt/sources.list.d/
    fi

    describe Running resolved test
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

}
