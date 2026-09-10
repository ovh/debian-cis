#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure GDM autorun-never is not overridden (Automated)
#

set -e
set -u

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Ensure GDM autorun-never cannot be overridden"

GDM_ANO_PACKAGES='gdm gdm3'
GDM_ANO_PROFILE='local'
GDM_ANO_DB_DIR='/etc/dconf/db'
GDM_ANO_KEYFILE='/etc/dconf/db/local.d/00-media-autorun'
GDM_ANO_LOCKFILE='/etc/dconf/db/local.d/locks/00-media-autorun'

GDM_ANO_INSTALLED=1

audit() {
    for l_package in $GDM_ANO_PACKAGES; do
        is_pkg_installed "$l_package"
        if [ "$FNRET" = 0 ]; then
            ok "Package $l_package is installed"
            GDM_ANO_INSTALLED=0
            break
        fi
    done

    if [ "$GDM_ANO_INSTALLED" -ne 0 ]; then
        ok "GNOME Desktop Manager package is not installed on the system - Recommendation is not applicable"
        return
    fi

    if grep -Psirq -- '^\h*\[org/gnome/desktop/media-handling\]\h*$' "$GDM_ANO_DB_DIR" 2>/dev/null; then
        ok "[org/gnome/desktop/media-handling] section found"
    else
        crit "[org/gnome/desktop/media-handling] setting not found in $GDM_ANO_DB_DIR"
    fi

    if grep -Pqrs -- '^\h*autorun-never\h*=\h*true\b' "$GDM_ANO_DB_DIR"/local.d/* 2>/dev/null; then
        ok "autorun-never setting found"
    else
        crit "autorun-never setting not found"
    fi

    if grep -Prilq -- '/org/gnome/desktop/media-handling/autorun-never\b' "$GDM_ANO_DB_DIR"/*/locks 2>/dev/null; then
        ok "autorun-never is locked"
    else
        crit "autorun-never is not locked"
    fi
}

apply() {
    if [ "$GDM_ANO_INSTALLED" -ne 0 ]; then
        ok "GNOME Desktop Manager is not installed, nothing to apply"
        return
    fi

    mkdir -p /etc/dconf/profile "/etc/dconf/db/${GDM_ANO_PROFILE}.d/locks"

    if [ ! -f /etc/dconf/profile/user ]; then
        {
            echo "user-db:user"
            echo "system-db:${GDM_ANO_PROFILE}"
        } >/etc/dconf/profile/user
    elif ! grep -Pq "^\h*system-db:${GDM_ANO_PROFILE}\b" /etc/dconf/profile/user; then
        sed -i '/^\s*system-db:/d' /etc/dconf/profile/user
        echo "system-db:${GDM_ANO_PROFILE}" >>/etc/dconf/profile/user
    fi

    if [ -f "$GDM_ANO_KEYFILE" ]; then
        sed -i '/^\s*autorun-never\s*=/d' "$GDM_ANO_KEYFILE"
    else
        echo "[org/gnome/desktop/media-handling]" >"$GDM_ANO_KEYFILE"
    fi

    if ! grep -q '^\[org/gnome/desktop/media-handling\]' "$GDM_ANO_KEYFILE"; then
        echo "[org/gnome/desktop/media-handling]" >>"$GDM_ANO_KEYFILE"
    fi
    sed -i '/^\[org\/gnome\/desktop\/media-handling\]/a autorun-never=true' "$GDM_ANO_KEYFILE"

    if [ -f "$GDM_ANO_LOCKFILE" ]; then
        sed -i '/\/org\/gnome\/desktop\/media-handling\/autorun-never/d' "$GDM_ANO_LOCKFILE"
    fi
    echo '/org/gnome/desktop/media-handling/autorun-never' >>"$GDM_ANO_LOCKFILE"

    if command -v dconf >/dev/null 2>&1; then
        dconf update
    fi

    ok "autorun-never is set and locked"
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
