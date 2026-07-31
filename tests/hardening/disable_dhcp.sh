# shellcheck shell=bash
# run-shellcheck
test_audit() {
    if ! apt-cache show isc-dhcp-server >/dev/null 2>&1; then
        describe "isc-dhcp-server package is unavailable - skipping"
        skip
        register_test retvalshouldbe 0
        # shellcheck disable=2154
        run skipped "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
        return
    fi

    describe "Prepare non-compliant state - install isc-dhcp-server"
    DEBIAN_FRONTEND=noninteractive apt-get install -y isc-dhcp-server || true

    # Ensure we can actually create a non-compliant state.
    if "${CIS_CHECKS_DIR}/${script}.sh" --audit-all >/dev/null 2>&1; then
        if systemctl >/dev/null 2>&1; then
            systemctl unmask isc-dhcp-server.service isc-dhcp-server6.service >/dev/null 2>&1 || true
            systemctl enable isc-dhcp-server.service isc-dhcp-server6.service >/dev/null 2>&1 || true
            systemctl start isc-dhcp-server.service isc-dhcp-server6.service >/dev/null 2>&1 || true
        fi
    fi

    if "${CIS_CHECKS_DIR}/${script}.sh" --audit-all >/dev/null 2>&1; then
        describe "Unable to create a non-compliant isc-dhcp-server state - skipping remediation path"
        skip
        register_test retvalshouldbe 0
        # shellcheck disable=2154
        run skipped "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
        describe "Clean installation"
        apt-get purge -y isc-dhcp-server || true
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
    apt-get purge -y isc-dhcp-server || true
    apt-get autoremove -y || true
}
