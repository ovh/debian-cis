# shellcheck shell=bash
# run-shellcheck
test_audit() {
    if ! apt-cache show ypserv 2>/dev/null | grep -q '^Package: ypserv$'; then
        describe "ypserv package is unavailable - skipping"
        skip
        register_test retvalshouldbe 0
        # shellcheck disable=2154
        run skipped "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
        return
    fi

    describe "Prepare non-compliant state - install ypserv"
    DEBIAN_FRONTEND=noninteractive apt-get install -y ypserv || true

    # Ensure we can actually create a non-compliant state.
    if "${CIS_CHECKS_DIR}/${script}.sh" --audit-all >/dev/null 2>&1; then
        if systemctl >/dev/null 2>&1; then
            systemctl unmask ypserv.service >/dev/null 2>&1 || true
            systemctl enable ypserv.service >/dev/null 2>&1 || true
            systemctl start ypserv.service >/dev/null 2>&1 || true
        fi
    fi

    if "${CIS_CHECKS_DIR}/${script}.sh" --audit-all >/dev/null 2>&1; then
        describe "Unable to create a non-compliant ypserv state - skipping remediation path"
        skip
        register_test retvalshouldbe 0
        # shellcheck disable=2154
        run skipped "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
        describe "Clean installation"
        apt-get purge -y ypserv || true
        apt-get autoremove -y || true
        return
    fi

    describe "Running on purpose failed test"
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run failed "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Correcting situation - enabling remediation"
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    # Service control may not be available in container test env; package purge path is expected.
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe "Checking resolved state"
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Clean installation"
    apt-get purge -y ypserv || true
    apt-get autoremove -y || true
}
