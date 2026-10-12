# shellcheck shell=bash
# run-shellcheck
test_audit() {
    if ! systemctl >/dev/null 2>&1; then
        skip "Test requires working systemd service management for cron"
        return
    fi

    DEBIAN_FRONTEND=noninteractive apt-get install -y cron >/dev/null 2>&1 || {
        skip "Cannot install cron, skipping tests"
        return
    }

    systemctl disable cron >/dev/null 2>&1 || true

    describe cron installed but disabled
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # shellcheck disable=2154
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    # shellcheck disable=2154
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe cron enabled
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    systemctl disable cron >/dev/null 2>&1 || true
    apt-get purge -y cron >/dev/null 2>&1 || true
    apt-get autoremove -y >/dev/null 2>&1 || true
}
