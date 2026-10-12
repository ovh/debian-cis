# shellcheck shell=bash
# run-shellcheck
test_audit() {
    if ! apt-cache show avahi-daemon 2>/dev/null | grep -q '^Package: avahi-daemon$'; then
        describe "avahi-daemon package is unavailable - skipping"
        skip
        register_test retvalshouldbe 0
        # shellcheck disable=2154
        run skipped "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
        return
    fi

    describe "Prepare non-compliant state - install avahi-daemon"
    DEBIAN_FRONTEND=noninteractive apt-get install -y avahi-daemon || true

    # Ensure we can actually create a non-compliant state:
    # - If package is not a dependency, audit already returns non-compliant.
    # - If package is a dependency, try to enable/start service and socket.
    if "${CIS_CHECKS_DIR}/${script}.sh" --audit-all >/dev/null 2>&1; then
        if systemctl >/dev/null 2>&1; then
            systemctl unmask avahi-daemon.socket avahi-daemon.service >/dev/null 2>&1 || true
            systemctl enable avahi-daemon.socket avahi-daemon.service >/dev/null 2>&1 || true
            systemctl start avahi-daemon.socket avahi-daemon.service >/dev/null 2>&1 || true
        fi
    fi

    if "${CIS_CHECKS_DIR}/${script}.sh" --audit-all >/dev/null 2>&1; then
        describe "Unable to create a non-compliant avahi state - skipping remediation path"
        skip
        register_test retvalshouldbe 0
        # shellcheck disable=2154
        run skipped "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
        describe "Clean installation"
        apt-get purge -y avahi-daemon || true
        apt-get autoremove -y || true
        return
    fi

    describe "Running on purpose failed test"
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Correcting situation - enabling remediation"
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe "Checking resolved state"
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Clean installation"
    apt-get purge -y avahi-daemon || true
    apt-get autoremove -y || true
}
