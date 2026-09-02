# shellcheck shell=bash
# run-shellcheck

is_running_in_container() {
    awk -F/ '$2 == "'"$1"'"' /proc/self/cgroup
}

test_audit() {
    if [ -n "$(is_running_in_container "docker")" ] ||
        [ -n "$(is_running_in_container "lxc")" ] ||
        [ -n "$(is_running_in_container "kubepods")" ]; then
        skip "SKIPPED on container: test writes dconf system profile/locks and runs dconf update, which is unreliable or non-representative in containerized environments"
        return
    fi

    describe Installing GDM package
    DEBIAN_FRONTEND=noninteractive apt-get install -y gdm3 >/dev/null 2>&1 || {
        skip "SKIPPED: cannot install gdm3"
        return
    }

    local profile_file="/etc/dconf/profile/user"
    local settings_file="/etc/dconf/db/local.d/00-screensaver"
    local lock_file="/etc/dconf/db/local.d/locks/00-screensaver"

    local profile_backup="/tmp/gdm_slo_profile.bak.$$"
    local settings_backup="/tmp/gdm_slo_settings.bak.$$"
    local lock_backup="/tmp/gdm_slo_lock.bak.$$"

    if [ -f "$profile_file" ]; then
        cp "$profile_file" "$profile_backup"
    fi
    if [ -f "$settings_file" ]; then
        cp "$settings_file" "$settings_backup"
    fi
    if [ -f "$lock_file" ]; then
        cp "$lock_file" "$lock_backup"
    fi

    describe Create non-compliant state
    mkdir -p /etc/dconf/profile /etc/dconf/db/local.d/locks
    cat >"$profile_file" <<'EOF'
user-db:user
system-db:local
EOF
    cat >"$settings_file" <<'EOF'
[org/gnome/desktop/session]
idle-delay=uint32 900
[org/gnome/desktop/screensaver]
lock-delay=uint32 5
EOF
    : >"$lock_file"
    dconf update 2>/dev/null || true

    register_test retvalshouldbe 1
    register_test contain "idle-delay is not locked"
    register_test contain "lock-delay is not locked"
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Correcting situation
    # shellcheck disable=2154
    sed -i 's/audit/enabled/' "${CIS_CONF_DIR}/conf.d/${script}.cfg"
    "${CIS_CHECKS_DIR}/${script}.sh" --apply || true

    describe Re-audit compliant state
    register_test retvalshouldbe 0
    register_test contain "idle-delay is locked"
    register_test contain "lock-delay is locked"
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    describe Restore/cleanup
    rm -f "$profile_file" "$settings_file" "$lock_file"
    if [ -f "$profile_backup" ]; then
        mv "$profile_backup" "$profile_file"
    fi
    if [ -f "$settings_backup" ]; then
        mkdir -p /etc/dconf/db/local.d
        mv "$settings_backup" "$settings_file"
    fi
    if [ -f "$lock_backup" ]; then
        mkdir -p /etc/dconf/db/local.d/locks
        mv "$lock_backup" "$lock_file"
    fi
    dconf update 2>/dev/null || true

    DEBIAN_FRONTEND=noninteractive apt-get remove -y gdm3 >/dev/null 2>&1 || true
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y >/dev/null 2>&1 || true
}
