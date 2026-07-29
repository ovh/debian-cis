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

    local test_pkg="gnome-shell"
    local test_profile="/etc/dconf/profile/user"
    local test_settings="/etc/dconf/db/local.d/00-screensaver"
    local test_backup_profile="/tmp/dconf_profile.bak.$$"
    local test_backup_settings="/tmp/dconf_settings.bak.$$"
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
    if [ -f "$test_profile" ]; then
        cp "$test_profile" "$test_backup_profile"
    fi
    if [ -f "$test_settings" ]; then
        cp "$test_settings" "$test_backup_settings"
    fi

    # Create non-conform scenario
    describe Tests purposely failing
    mkdir -p /etc/dconf/db/local.d
    cat >"$test_settings" <<'EOF'
[org/gnome/desktop/screensaver]
idle-activation-enabled=false
lock-enabled=false
EOF
    dconf update 2>/dev/null || true
    register_test retvalshouldbe 1
    register_test contain "missing or incorrect"
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Apply remediation
    describe correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    # Verify conform scenario
    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "correctly configured"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Test duplicate keys scenario (wrong values should be replaced, not appended)
    describe Tests with duplicate keys with wrong values
    cat >"$test_profile" <<'EOF'
user-db:wrong
system-db:wrong
EOF
    register_test retvalshouldbe 1
    register_test contain "missing"
    run duplicate_keys_audit "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Apply should fix without creating duplicates
    describe Fixing duplicate keys
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    # Verify no duplicates after apply
    describe Checking no duplicate keys after fix
    register_test retvalshouldbe 0
    run duplicate_keys_resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Count occurrences of user-db and system-db keys
    local user_db_count
    local system_db_count
    user_db_count=$(grep -c "^user-db:" "$test_profile" || true)
    system_db_count=$(grep -c "^system-db:" "$test_profile" || true)

    if [ "$user_db_count" -ne 1 ] || [ "$system_db_count" -ne 1 ]; then
        fail "Duplicate keys found: user-db count=$user_db_count, system-db count=$system_db_count"
    else
        ok "No duplicate keys after apply"
    fi

    # Cleanup
    if [ -f "$test_backup_profile" ]; then
        mv "$test_backup_profile" "$test_profile"
    fi
    if [ -f "$test_backup_settings" ]; then
        mv "$test_backup_settings" "$test_settings"
    fi
    dconf update 2>/dev/null || true

    # Restore package state
    if [ "$pkg_was_installed" -eq 0 ]; then
        apt-get remove -y "$test_pkg" >/dev/null 2>&1 || true
    fi
}
