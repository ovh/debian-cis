# shellcheck shell=bash
# run-shellcheck
test_audit() {
    local grub_file="/etc/default/grub"
    # shellcheck disable=2154
    local script_cfg="${CIS_CONF_DIR}/conf.d/${script}.cfg"
    # shellcheck disable=2154
    local grub_backup="/tmp/${script}.grub.backup.$$"
    # shellcheck disable=2154
    local cfg_backup="/tmp/${script}.cfg.backup.$$"
    local grub_existed=1
    local cfg_existed=1

    if [ -f "$grub_file" ]; then
        cp "$grub_file" "$grub_backup"
    else
        grub_existed=0
    fi

    if [ -f "$script_cfg" ]; then
        cp "$script_cfg" "$cfg_backup"
    else
        cfg_existed=0
    fi

    describe "Running non-compliant scenario (missing grub default file)"
    rm -f "$grub_file"
    register_test retvalshouldbe 1
    register_test contain "$grub_file does not exist"
    # shellcheck disable=2154
    run missing_file "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Running non-compliant scenario (audit_backlog_limit absent)"
    cat >"$grub_file" <<'EOF'
GRUB_CMDLINE_LINUX=""
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
EOF
    register_test retvalshouldbe 1
    run missing_value "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Running non-compliant scenario (audit_backlog_limit too low)"
    cat >"$grub_file" <<'EOF'
GRUB_CMDLINE_LINUX="audit_backlog_limit=1024"
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
EOF
    register_test retvalshouldbe 1
    register_test contain "audit_backlog_limit=1024 in GRUB_CMDLINE_LINUX is lower than"
    run too_low "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Running non-compliant scenario (audit_backlog_limit invalid)"
    cat >"$grub_file" <<'EOF'
GRUB_CMDLINE_LINUX="audit_backlog_limit=abc"
EOF
    register_test retvalshouldbe 1
    run invalid "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Running compliant scenario (only set in GRUB_CMDLINE_LINUX_DEFAULT)"
    cat >"$grub_file" <<'EOF'
GRUB_CMDLINE_LINUX=""
GRUB_CMDLINE_LINUX_DEFAULT="quiet ipv6.disable=1 audit=1 audit_backlog_limit=8192 amd_iommu=off"
EOF
    register_test retvalshouldbe 0
    run default_only "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Running non-compliant scenario (overridden by a lower value in GRUB_CMDLINE_LINUX_DEFAULT)"
    cat >"$grub_file" <<'EOF'
GRUB_CMDLINE_LINUX="audit_backlog_limit=8192"
GRUB_CMDLINE_LINUX_DEFAULT="quiet audit_backlog_limit=64"
EOF
    register_test retvalshouldbe 1
    register_test contain "audit_backlog_limit=64 in GRUB_CMDLINE_LINUX_DEFAULT is lower than"
    run overridden "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Running compliant scenario (value greater than minimum)"
    cat >"$grub_file" <<'EOF'
GRUB_CMDLINE_LINUX="quiet audit_backlog_limit=16384"
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
EOF
    register_test retvalshouldbe 0
    run compliant_greater "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Running apply from non-compliant state (low values, other options present)"
    cat >"$grub_file" <<'EOF'
GRUB_CMDLINE_LINUX="audit=1 audit_backlog_limit=1024 apparmor=1"
GRUB_CMDLINE_LINUX_DEFAULT="quiet audit_backlog_limit=64"
EOF
    sed -i 's/audit/enabled/' "$script_cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe "Checking resolved state after apply"
    register_test retvalshouldbe 0
    run resolved_low "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe "Running apply from non-compliant state (GRUB_CMDLINE_LINUX absent)"
    cat >"$grub_file" <<'EOF'
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
EOF
    "${CIS_CHECKS_DIR}/${script}.sh" || true

    describe "Checking resolved state after apply"
    register_test retvalshouldbe 0
    run resolved_absent "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

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
