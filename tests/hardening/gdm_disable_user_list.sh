# run-shellcheck
test_audit() {
    if [ -f "/.dockerenv" ]; then
        skip "Not running in docker container"
        return
    fi

    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    local test_pkg="gdm3"
    local test_file="/etc/gdm3/greeter.dconf-defaults"
    local test_backup="/tmp/gdm3_greeter.bak.$$"
    local pkg_was_installed=0

    # Check if package is currently installed
    if dpkg-query -W "$test_pkg" >/dev/null 2>&1; then
        pkg_was_installed=1
    fi

    # Test 1: Package not installed scenario
    if [ "$pkg_was_installed" -eq 1 ]; then
        describe Package not installed scenario
        apt-get remove -y "$test_pkg" >/dev/null 2>&1 || true
    fi
    register_test retvalshouldbe 0
    register_test contain "is not installed"
    run pkg_not_installed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Test 2: Package installed scenario
    describe Installing package for testing
    apt-get install -y "$test_pkg" >/dev/null 2>&1 || {
        skip "Cannot install $test_pkg, skipping package installed tests"
        return
    }

    # Backup existing configuration
    if [ -f "$test_file" ]; then
        cp "$test_file" "$test_backup"
    fi

    # Create non-conform scenario
    describe Tests purposely failing
    mkdir -p /etc/gdm3
    echo "[org/gnome/login-screen]" >"$test_file"
    echo "disable-user-list=false" >>"$test_file"
    register_test retvalshouldbe 1
    register_test contain "is not set to true"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Apply remediation
    describe correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    # Verify conform scenario
    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "correctly set"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Test duplicate keys scenario (multiple keys with wrong values should be replaced, not appended)
    describe Tests with duplicate keys
    cat >"$test_file" <<'EOF'
[org/gnome/login-screen]
disable-user-list=false
disable-user-list=wrong
EOF
    register_test retvalshouldbe 1
    register_test contain "is not set to true"
    run duplicate_keys_audit "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Apply should fix without creating duplicates
    describe Fixing duplicate keys
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    # Verify no duplicates after apply
    describe Checking no duplicate keys after fix
    register_test retvalshouldbe 0
    run duplicate_keys_resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Count occurrences of disable-user-list key
    local key_count
    key_count=$(grep -c "^[[:space:]]*disable-user-list" "$test_file" || true)

    if [ "$key_count" -ne 1 ]; then
        fail "Duplicate keys found: disable-user-list count=$key_count"
    else
        ok "No duplicate keys after apply"
    fi

    # Cleanup
    if [ -f "$test_backup" ]; then
        mv "$test_backup" "$test_file"
    fi

    # Restore package state
    if [ "$pkg_was_installed" -eq 0 ]; then
        apt-get remove -y "$test_pkg" >/dev/null 2>&1 || true
    fi
}
