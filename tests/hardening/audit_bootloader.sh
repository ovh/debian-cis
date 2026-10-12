# shellcheck shell=bash
# run-shellcheck
test_audit() {
    local grub_file="/etc/default/grub"
    # shellcheck disable=2154
    local script_cfg="${CIS_CONF_DIR}/conf.d/${script}.cfg"
    local grub_backup="/tmp/${script}.grub.backup.$$"
    local cfg_backup="/tmp/${script}.cfg.backup.$$"
    local grub_existed=1
    local cfg_existed=1

    if [ ! -f "$grub_file" ]; then
        grub_existed=0
    else
        cp "$grub_file" "$grub_backup"
    fi

    if [ ! -f "$script_cfg" ]; then
        cfg_existed=0
    else
        cp "$script_cfg" "$cfg_backup"
    fi

    describe "Running non-compliant scenario (missing audit=1 in both variables)"
    cat >"$grub_file" <<'EOF'
GRUB_CMDLINE_LINUX=""
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
EOF
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Running compliant scenario with audit=1 in GRUB_CMDLINE_LINUX only"
    cat >"$grub_file" <<'EOF'
GRUB_CMDLINE_LINUX="audit=1"
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
EOF
    register_test retvalshouldbe 0
    run compliant_linux "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Running compliant scenario with audit=1 in GRUB_CMDLINE_LINUX_DEFAULT only"
    cat >"$grub_file" <<'EOF'
GRUB_CMDLINE_LINUX=""
GRUB_CMDLINE_LINUX_DEFAULT="quiet audit=1"
EOF
    register_test retvalshouldbe 0
    run compliant_linux_default "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Running apply from non-compliant state"
    cat >"$grub_file" <<'EOF'
GRUB_CMDLINE_LINUX=""
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
EOF
    sed -i 's/audit/enabled/' "$script_cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe "Checking resolved state after apply"
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Restoring host state"
    if [ "$grub_existed" -eq 1 ]; then
        mv "$grub_backup" "$grub_file"
    else
        rm -f "$grub_file"
    fi

    if [ "$cfg_existed" -eq 1 ]; then
        mv "$cfg_backup" "$script_cfg"
    else
        rm -f "$script_cfg"
    fi
}
