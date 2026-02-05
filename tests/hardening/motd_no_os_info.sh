# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    local test_file="/etc/motd"
    local test_backup="/tmp/motd.bak.$$"

    # Backup existing motd if present
    if [ -f "$test_file" ]; then
        cp "$test_file" "$test_backup"
    fi

    # Create non-conform scenario
    describe Tests purposely failing
    printf '%s\n' "Welcome \\v on \\r \\m \\s" >"$test_file"
    register_test retvalshouldbe 1
    register_test contain "contains OS information"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Apply remediation
    describe correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    # Verify conform scenario
    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "does not contain OS information"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    rm -f "$test_file"
    if [ -f "$test_backup" ]; then
        mv "$test_backup" "$test_file"
    fi
}
