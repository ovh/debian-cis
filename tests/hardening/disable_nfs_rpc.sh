# shellcheck shell=bash
# run-shellcheck
test_audit() {
    if ! apt-cache show nfs-kernel-server >/dev/null 2>&1; then
        describe "nfs-kernel-server package is unavailable - skipping"
        skip
        register_test retvalshouldbe 0
        # shellcheck disable=2154
        run skipped "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
        return
    fi

    describe "Prepare non-compliant state - install nfs-kernel-server"
    DEBIAN_FRONTEND=noninteractive apt-get install -y nfs-kernel-server || true

    # Ensure we can actually create a non-compliant state.
    if "${CIS_CHECKS_DIR}/${script}.sh" --audit-all >/dev/null 2>&1; then
        if is_systemctl_running; then
            systemctl unmask nfs-server.service >/dev/null 2>&1 || true
            systemctl enable nfs-server.service >/dev/null 2>&1 || true
            systemctl start nfs-server.service >/dev/null 2>&1 || true
        fi
    fi

    if "${CIS_CHECKS_DIR}/${script}.sh" --audit-all >/dev/null 2>&1; then
        describe "Unable to create a non-compliant nfs-kernel-server state - skipping remediation path"
        skip
        register_test retvalshouldbe 0
        # shellcheck disable=2154
        run skipped "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
        describe "Clean installation"
        apt-get purge -y nfs-kernel-server || true
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
    apt-get purge -y nfs-kernel-server || true
    apt-get autoremove -y || true
}
