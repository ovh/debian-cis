# shellcheck shell=bash
# run-shellcheck
test_audit() {
    perms_backup=$(mktemp)
    logs_list=$(mktemp)
    fixture_file="/var/log/cis_logs_permissions_fixture.log"

    find /var/log -type f >"$logs_list"

    while IFS= read -r logfile; do
        mode=$(stat -L -c "%a" "$logfile" 2>/dev/null || true)
        if [ -n "$mode" ]; then
            printf '%s|%s\n' "$mode" "$logfile" >>"$perms_backup"
            chmod 0640 "$logfile" 2>/dev/null || true
        fi
    done <"$logs_list"

    : >"$fixture_file"
    chmod 0666 "$fixture_file"

    describe non compliant log permission
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe correcting situation
    # shellcheck disable=2154
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    # shellcheck disable=2154
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe checking resolved state
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    rm -f "$fixture_file"

    while IFS='|' read -r mode logfile; do
        if [ -f "$logfile" ] && [ -n "$mode" ]; then
            chmod "0$mode" "$logfile" 2>/dev/null || true
        fi
    done <"$perms_backup"

    rm -f "$perms_backup" "$logs_list"
}
