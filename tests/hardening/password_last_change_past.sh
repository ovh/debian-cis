# shellcheck shell=bash
# run-shellcheck
test_audit() {
    shadow_backup=$(mktemp)
    shadow_tmp=$(mktemp)
    today_days=$(($(date +%s) / 86400))
    future_days=$((today_days + 30))
    test_user="cis_pwd_future_test"
    # shellcheck disable=SC2016
    pwd_hash='$6$rounds=656000$abcdefghijklmnop$2sZJdgXLxVFTGvQ.zFhZ8.h6n7J8KmQ3M9pLlR2wxN1D5Zx8eV9Q4yT8uJ3Qm'

    cp -f /etc/shadow "$shadow_backup"

    useradd -M -s /usr/sbin/nologin "$test_user" >/dev/null 2>&1 || true

    awk -F: -v OFS=: -v u="$test_user" -v d="$future_days" -v hash="$pwd_hash" '
        $1==u { $2=hash; $3=d; print; next }
        { print }
    ' /etc/shadow >"$shadow_tmp"
    cat "$shadow_tmp" >/etc/shadow

    describe user with future last password change date
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    awk -F: -v OFS=: -v u="$test_user" -v d="$today_days" -v hash="$pwd_hash" '
        $1==u { $2=hash; $3=d; print; next }
        { print }
    ' /etc/shadow >"$shadow_tmp"
    cat "$shadow_tmp" >/etc/shadow

    describe user last password change moved to past
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # Test with locked user account (password starting with !)
    test_user_locked="cis_pwd_locked_test"
    useradd -M -s /usr/sbin/nologin "$test_user_locked" >/dev/null 2>&1 || true

    awk -F: -v OFS=: -v u="$test_user_locked" -v d="$future_days" '
        $1==u { $2="!"; $3=d; print; next }
        { print }
    ' /etc/shadow >"$shadow_tmp"
    cat "$shadow_tmp" >/etc/shadow

    describe "locked user with future last password change date - should be OK"
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    cp -f "$shadow_backup" /etc/shadow

    userdel -f "$test_user" >/dev/null 2>&1 || true
    userdel -f "$test_user_locked" >/dev/null 2>&1 || true

    rm -f "$shadow_backup" "$shadow_tmp" || true
}
