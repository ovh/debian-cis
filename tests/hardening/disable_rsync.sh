# shellcheck shell=bash
# run-shellcheck
test_audit() {
    rsync_backup=""

    DEBIAN_FRONTEND=noninteractive apt-get install -y rsync >/dev/null 2>&1 || {
        skip "Unable to install rsync package"
        return
    }

    if [ -f /etc/default/rsync ]; then
        rsync_backup=$(mktemp)
        cp /etc/default/rsync "$rsync_backup"
    fi

    cat <<'EOF' >/etc/default/rsync
RSYNC_ENABLE=true
EOF

    describe rsync enabled
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # shellcheck disable=2154
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    # shellcheck disable=2154
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe rsync disabled in config
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    if [ -n "$rsync_backup" ]; then
        cp "$rsync_backup" /etc/default/rsync
        rm -f "$rsync_backup"
    else
        rm -f /etc/default/rsync
    fi

    apt-get purge -y rsync >/dev/null 2>&1 || true
    apt-get autoremove -y >/dev/null 2>&1 || true
}
