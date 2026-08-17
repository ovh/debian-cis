# shellcheck shell=bash
# run-shellcheck
test_audit() {
    limits_backup=$(mktemp)
    limitsd_backup=$(mktemp -d)

    if [ ! -w /etc/security/limits.conf ]; then
        rm -f "$limits_backup"
        rm -rf "$limitsd_backup"
        skip "SKIPPED: /etc/security/limits.conf is not writable"
        return
    fi

    if ! sysctl fs.suid_dumpable >/dev/null 2>&1; then
        rm -f "$limits_backup"
        rm -rf "$limitsd_backup"
        skip "SKIPPED: fs.suid_dumpable sysctl is not available"
        return
    fi

    original_suid_dumpable=$(sysctl -n fs.suid_dumpable 2>/dev/null || true)
    if [ -z "$original_suid_dumpable" ]; then
        rm -f "$limits_backup"
        rm -rf "$limitsd_backup"
        skip "SKIPPED: unable to read fs.suid_dumpable value"
        return
    fi

    cp /etc/security/limits.conf "$limits_backup"
    if [ -d /etc/security/limits.d ]; then
        cp -a /etc/security/limits.d "$limitsd_backup/limits.d"
    fi

    # Build a controlled non-compliant state without using --apply.
    sed -i '/^\*[[:space:]]*hard[[:space:]]*core[[:space:]]*0$/d' /etc/security/limits.conf
    if [ -d /etc/security/limits.d ]; then
        for limits_file in /etc/security/limits.d/*.conf; do
            [ -f "$limits_file" ] || continue
            sed -i '/^\*[[:space:]]*hard[[:space:]]*core[[:space:]]*0$/d' "$limits_file"
        done
    fi

    if ! sysctl -w fs.suid_dumpable=1 >/dev/null 2>&1; then
        cp "$limits_backup" /etc/security/limits.conf
        if [ -d "$limitsd_backup/limits.d" ]; then
            rm -rf /etc/security/limits.d
            cp -a "$limitsd_backup/limits.d" /etc/security/limits.d
        fi
        sysctl -w fs.suid_dumpable="$original_suid_dumpable" >/dev/null 2>&1 || true
        rm -f "$limits_backup"
        rm -rf "$limitsd_backup"
        skip "SKIPPED: unable to set fs.suid_dumpable=1 in this environment"
        return
    fi

    describe non compliant state
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Build a compliant state manually (audit-only strategy).
    echo "* hard core 0" >>/etc/security/limits.conf
    sysctl -w fs.suid_dumpable=0 >/dev/null 2>&1 || true

    describe compliant state
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    cp "$limits_backup" /etc/security/limits.conf
    if [ -d "$limitsd_backup/limits.d" ]; then
        rm -rf /etc/security/limits.d
        cp -a "$limitsd_backup/limits.d" /etc/security/limits.d
    fi
    sysctl -w fs.suid_dumpable="$original_suid_dumpable" >/dev/null 2>&1 || true

    rm -f "$limits_backup"
    rm -rf "$limitsd_backup"
}
