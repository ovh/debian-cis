# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    if [ -f "/.dockerenv" ]; then
        skip "SKIPPED on docker"
    else
        describe Tests purposely failing
        sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=0 2>/dev/null
        register_test retvalshouldbe 1
        register_test contain "net.ipv4.icmp_echo_ignore_broadcasts was not set to 1"

        run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

        describe correcting situation
        sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
        "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

        describe Checking resolved state
        register_test retvalshouldbe 0
        register_test contain "correctly set to 1"
        register_test contain "net.ipv4.icmp_echo_ignore_broadcasts correctly set to 1"
        run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
    fi
}
