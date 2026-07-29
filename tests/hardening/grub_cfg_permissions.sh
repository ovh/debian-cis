# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    local test_user="testgrubuser"
    local test_file="/boot/grub/grub.cfg"
    local grub_was_installed=0

    # Check if GRUB is currently installed
    if [ -f "$test_file" ]; then
        grub_was_installed=1
    fi

    # Test 1: GRUB not installed scenario
    if [ "$grub_was_installed" -eq 1 ]; then
        describe Package not installed scenario
        # Note: We can't actually remove GRUB package safely in a test
        # Instead, test by temporarily renaming the file
        mv "$test_file" "${test_file}.test_backup"
        register_test retvalshouldbe 0
        register_test contain "not found"
        run pkg_not_installed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
        # Restore the file
        mv "${test_file}.test_backup" "$test_file"
    else
        skip "GRUB not installed, cannot test package installed scenario"
        return
    fi

    # Test 2: GRUB installed scenario

    # Create non-conform scenario
    describe Tests purposely failing
    useradd "$test_user" --shell /bin/false 2>/dev/null || true
    chmod 777 "$test_file"
    chown "$test_user:$test_user" "$test_file" 2>/dev/null || chown 1000:1000 "$test_file"
    register_test retvalshouldbe 1
    register_test contain "ownership is incorrect"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Apply remediation
    describe correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    # Verify conform scenario
    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "has correct ownership and permissions"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Cleanup
    userdel -f "$test_user" 2>/dev/null || true
}
