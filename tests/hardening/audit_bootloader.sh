# shellcheck shell=bash
# run-shellcheck
test_audit() {
    grub_backup=""
    grub2_was_installed=0

    if dpkg -s grub2-common >/dev/null 2>&1; then
        grub2_was_installed=1
    else
        DEBIAN_FRONTEND=noninteractive apt-get install -y grub2-common >/dev/null 2>&1 || {
            skip "Cannot install grub2-common, skipping tests"
            return
        }
    fi

    if [ -f /etc/default/grub ]; then
        grub_backup=$(mktemp)
        cp /etc/default/grub "$grub_backup"
    fi

    printf '%s
' 'GRUB_CMDLINE_LINUX=quiet splash' >/etc/default/grub

    describe Running on non-compliant state
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    if [ -n "$grub_backup" ]; then
        cp "$grub_backup" /etc/default/grub
        rm -f "$grub_backup"
    else
        rm -f /etc/default/grub
    fi

    if [ "$grub2_was_installed" -ne 1 ]; then
        apt-get purge -y grub2-common >/dev/null 2>&1 || true
        apt-get autoremove -y >/dev/null 2>&1 || true
    fi
}
