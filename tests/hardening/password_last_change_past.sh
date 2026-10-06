# shellcheck shell=bash
# run-shellcheck
test_audit() {
    shadow_backup=$(mktemp)
    shadow_tmp=$(mktemp)
    today_days=$(($(date +%s) / 86400))
    future_days=$((today_days + 30))
    test_user="cis_pwd_future_test"
    had_test_user=0

    cp /etc/shadow "$shadow_backup"

    if getent passwd "$test_user" >/dev/null 2>&1; then
        had_test_user=1
    else
        useradd -M -s /usr/sbin/nologin "$test_user" >/dev/null 2>&1 || {
            rm -f "$shadow_backup" "$shadow_tmp"
            skip "SKIPPED: unable to create test user"
            return
        }
        echo "$test_user:Passw0rd!" | chpasswd >/dev/null 2>&1 || true
    fi

    awk -F: -v OFS=: -v u="$test_user" -v d="$future_days" '
        $1==u { $3=d; print; next }
        { print }
    ' /etc/shadow >"$shadow_tmp"
    cat "$shadow_tmp" >/etc/shadow

    describe user with future last password change date
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    awk -F: -v OFS=: -v u="$test_user" -v d="$today_days" '
        $1==u { $3=d; print; next }
        { print }
    ' /etc/shadow >"$shadow_tmp"
    cat "$shadow_tmp" >/etc/shadow

    describe user last password change moved to past
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    cp "$shadow_backup" /etc/shadow

    if [ "$had_test_user" -eq 0 ]; then
        userdel -f "$test_user" >/dev/null 2>&1 || true
    fi

    rm -f "$shadow_backup" "$shadow_tmp"
}
