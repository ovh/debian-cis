# shellcheck shell=bash
# run-shellcheck
test_audit() {
    test_user="testgrubowner"
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
        touch "$test_file"
    fi

    useradd "$test_user" --shell /bin/false 2>/dev/null || true
    chown "$test_user":"$test_user" "$test_file" 2>/dev/null || chown 1000:1000 "$test_file"
    chmod 777 "$test_file"

    describe Non compliant bootloader ownership
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    # shellcheck disable=2154
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    # shellcheck disable=2154
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    userdel -f "$test_user" >/dev/null 2>&1 || true
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
