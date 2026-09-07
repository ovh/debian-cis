#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure GDM screen locks cannot be overridden (Automated)
#

set -e
set -u

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Ensure GDM screen lock settings cannot be overridden"

GDM_SLO_PACKAGES='gdm gdm3'
GDM_SLO_DB_DIR='/etc/dconf/db'
GDM_SLO_PROFILE='local'
GDM_SLO_LOCK_FILE='/etc/dconf/db/local.d/locks/00-screensaver'

GDM_SLO_INSTALLED=1

audit() {
    for l_package in $GDM_SLO_PACKAGES; do
        is_pkg_installed "$l_package"
        if [ "$FNRET" = 0 ]; then
            ok "Package $l_package is installed"
            GDM_SLO_INSTALLED=0
            break
        fi
    done

    if [ "$GDM_SLO_INSTALLED" -ne 0 ]; then
        ok "GNOME Desktop Manager package is not installed on the system - Recommendation is not applicable"
        return
    fi

    local idle_file lock_file
    idle_file=$(grep -Psril -- '^\h*idle-delay\h*=\h*uint32\h*[1-9][0-9]*\b' "$GDM_SLO_DB_DIR" 2>/dev/null | head -n1 || true)
    lock_file=$(grep -Psril -- '^\h*lock-delay\h*=\h*uint32\h*[0-9]+\b' "$GDM_SLO_DB_DIR" 2>/dev/null | head -n1 || true)

    if [ -n "$idle_file" ]; then
        ok "idle-delay is set"
    else
        crit "idle-delay is not set so it cannot be locked"
    fi

    if [ -n "$lock_file" ]; then
        ok "lock-delay is set"
    else
        crit "lock-delay is not set so it cannot be locked"
    fi

    if grep -Prilq -- '/org/gnome/desktop/session/idle-delay\b' "$GDM_SLO_DB_DIR"/*/locks 2>/dev/null; then
        ok "idle-delay is locked"
    else
        crit "idle-delay is not locked"
    fi

    if grep -Prilq -- '/org/gnome/desktop/screensaver/lock-delay\b' "$GDM_SLO_DB_DIR"/*/locks 2>/dev/null; then
        ok "lock-delay is locked"
    else
        crit "lock-delay is not locked"
    fi
}

apply() {
    if [ "$GDM_SLO_INSTALLED" -ne 0 ]; then
        ok "GNOME Desktop Manager is not installed, nothing to apply"
        return
    fi

    mkdir -p "/etc/dconf/profile" "/etc/dconf/db/${GDM_SLO_PROFILE}.d/locks"

    if [ ! -f "/etc/dconf/profile/user" ]; then
        {
            echo "user-db:user"
            echo "system-db:${GDM_SLO_PROFILE}"
        } >"/etc/dconf/profile/user"
    elif ! grep -Pq "^\h*system-db:${GDM_SLO_PROFILE}\b" "/etc/dconf/profile/user"; then
        sed -i '/^\s*system-db:/d' "/etc/dconf/profile/user"
        echo "system-db:${GDM_SLO_PROFILE}" >>"/etc/dconf/profile/user"
    fi

    local settings_file="/etc/dconf/db/${GDM_SLO_PROFILE}.d/00-screensaver"
    if [ -f "$settings_file" ]; then
        sed -i '/^\s*idle-delay\s*=/d' "$settings_file"
        sed -i '/^\s*lock-delay\s*=/d' "$settings_file"
    else
        echo "[org/gnome/desktop/session]" >"$settings_file"
    fi

    if ! grep -q '^\[org/gnome/desktop/session\]' "$settings_file"; then
        echo "[org/gnome/desktop/session]" >>"$settings_file"
    fi
    if ! grep -q '^\[org/gnome/desktop/screensaver\]' "$settings_file"; then
        echo "[org/gnome/desktop/screensaver]" >>"$settings_file"
    fi
    sed -i '/^\[org\/gnome\/desktop\/session\]/a idle-delay=uint32 900' "$settings_file"
    sed -i '/^\[org\/gnome\/desktop\/screensaver\]/a lock-delay=uint32 5' "$settings_file"

    if [ -f "$GDM_SLO_LOCK_FILE" ]; then
        sed -i '/\/org\/gnome\/desktop\/session\/idle-delay/d' "$GDM_SLO_LOCK_FILE"
        sed -i '/\/org\/gnome\/desktop\/screensaver\/lock-delay/d' "$GDM_SLO_LOCK_FILE"
    fi

    {
        echo "/org/gnome/desktop/session/idle-delay"
        echo "/org/gnome/desktop/screensaver/lock-delay"
    } >>"$GDM_SLO_LOCK_FILE"

    if command -v dconf >/dev/null 2>&1; then
        dconf update
    fi

    ok "GDM screen lock override protection applied"
}

check_config() {
    :
}

if [ -r /etc/default/cis-hardening ]; then
    # shellcheck source=../../debian/default
    . /etc/default/cis-hardening
fi
if [ -z "${CIS_LIB_DIR}" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_LIB_DIR variable, aborting."
    exit 128
fi

if [ -r "${CIS_LIB_DIR}"/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "${CIS_LIB_DIR}"/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is ${CIS_LIB_DIR} in /etc/default/cis-hardening"
    exit 128
fi
