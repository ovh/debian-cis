# shellcheck shell=bash
# run-shellcheck
test_audit() {

    describe "Prepare on purpose failed test - install ypserv package"
    is_running_in_container() {
        grep -qE "(docker|lxc|kubepods)" /proc/self/cgroup
    }

    if is_running_in_container; then
        skip "Skipping test in container environment - package installation and service management may not be reliable"
        register_test retvalshouldbe 0
        return
    fi

    DEBIAN_FRONTEND=noninteractive apt-get install -y ypserv || true

    describe "Running on purpose failed test - ypserv installed"
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Correcting situation - applying remediation"
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe "Checking resolved state - ypserv should be removed or service stopped/masked"
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Clean installation - remove ypserv"
    if dpkg -s ypserv >/dev/null 2>&1; then
        apt-get remove -y ypserv || true
    fi
    apt-get autoremove -y || true

}
