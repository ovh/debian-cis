# shellcheck shell=bash
# run-shellcheck
test_audit() {
    test_file="/boot/grub/grub.cfg"
    test_file_backup=""
    created_test_file=0
    grub2_was_installed=0

    if dpkg -s grub2-common >/dev/null 2>&1; then
        grub2_was_installed=1
    else
        DEBIAN_FRONTEND=noninteractive apt-get install -y grub2-common >/dev/null 2>&1 || {
            skip "Cannot install grub2-common, skipping tests"
            return
        }
    fi

    mkdir -p /boot/grub
    if [ -f "$test_file" ]; then
        test_file_backup=$(mktemp)
        cp "$test_file" "$test_file_backup"
    else
        created_test_file=1
    fi

    cat <<'EOF' >"$test_file"
set timeout=5
menuentry 'Debian' {
    linux /vmlinuz
}
EOF

    describe Non compliant grub password state
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    cat <<'EOF' >"$test_file"
set superusers="root"
password_pbkdf2 root grub.pbkdf2.sha512.10000.fakehash
menuentry 'Debian' {
    linux /vmlinuz
}
EOF

    describe Compliant grub password state
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    if [ -n "$test_file_backup" ]; then
        cp "$test_file_backup" "$test_file"
        rm -f "$test_file_backup"
    elif [ "$created_test_file" -eq 1 ]; then
        rm -f "$test_file"
    fi

    if [ "$grub2_was_installed" -ne 1 ]; then
        apt-get purge -y grub2-common >/dev/null 2>&1 || true
        apt-get autoremove -y >/dev/null 2>&1 || true
    fi
}
