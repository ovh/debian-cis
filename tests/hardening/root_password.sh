# shellcheck shell=bash
# run-shellcheck
test_audit() {
    shadow_backup=$(mktemp)
    shadow_tmp=$(mktemp)
    shadow_mode=$(stat -c "%a" /etc/shadow)
    shadow_owner=$(stat -c "%u:%g" /etc/shadow)

    cp /etc/shadow "$shadow_backup"

    awk -F: 'BEGIN{OFS=":"} $1=="root" {$2="!"} {print}' /etc/shadow >"$shadow_tmp"
    cat "$shadow_tmp" >/etc/shadow

    describe root account locked in shadow
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    cp "$shadow_backup" /etc/shadow

    if grep -qE '^root:[*!]:' /etc/shadow; then
        awk -F: 'BEGIN{OFS=":"} $1=="root" {$2="$6$cis$notrealhash"} {print}' /etc/shadow >"$shadow_tmp"
        cat "$shadow_tmp" >/etc/shadow
    fi

    describe root account not locked in shadow
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    cp "$shadow_backup" /etc/shadow
    chown "$shadow_owner" /etc/shadow
    chmod "$shadow_mode" /etc/shadow

    rm -f "$shadow_backup" "$shadow_tmp"
}
