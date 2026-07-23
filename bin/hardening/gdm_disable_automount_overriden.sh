#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
#  Ensure GDM disabling automatic mounting of removable media is not overridden (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure GDM disabling automatic mounting of removable media is not overridden."

PACKAGES='gdm gdm3'
DCONF_DB_DIR='/etc/dconf/db/local.d'

# Global state
GDM_DA_INSTALLED=0
GDM_DA_AUTOMOUNT_OK=0
GDM_DA_AUTOMOUNT_OPEN_OK=0

# This function will be called if the script status is on enabled / audit mode
audit() {
    # Check if GNOME Desktop Manager is installed
    for l_package in $PACKAGES; do
        is_pkg_installed "$l_package"
        if [ "$FNRET" = 0 ]; then
            ok "Package $l_package is installed"
            GDM_DA_INSTALLED=1
            break
        fi
    done

    if [ "$GDM_DA_INSTALLED" -eq 0 ]; then
        ok "GNOME Desktop Manager package is not installed on the system - Recommendation is not applicable"
        return
    fi

    # Search /etc/dconf/db/local.d/ for automount settings
    local l_automount_setting
    local l_automount_open_setting

    l_automount_setting=$(grep -Psir -- '^\h*automount\h*=\h*false\b' "$DCONF_DB_DIR" 2>/dev/null || true)
    l_automount_open_setting=$(grep -Psir -- '^\h*automount-open\h*=\h*false\b' "$DCONF_DB_DIR" 2>/dev/null || true)

    # Check for automount setting
    if [ -n "$l_automount_setting" ]; then
        ok "automount setting found and set to false"
        GDM_DA_AUTOMOUNT_OK=1
    else
        crit "automount setting not found or not set to false in $DCONF_DB_DIR"
        GDM_DA_AUTOMOUNT_OK=0
    fi

    # Check for automount-open setting
    if [ -n "$l_automount_open_setting" ]; then
        ok "automount-open setting found and set to false"
        GDM_DA_AUTOMOUNT_OPEN_OK=1
    else
        crit "automount-open setting not found or not set to false in $DCONF_DB_DIR"
        GDM_DA_AUTOMOUNT_OPEN_OK=0
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$GDM_DA_INSTALLED" -eq 0 ]; then
        ok "GNOME Desktop Manager is not installed, nothing to apply"
        return
    fi

    # Create the directory if it doesn't exist
    if [ ! -d "$DCONF_DB_DIR" ]; then
        info "Creating directory $DCONF_DB_DIR"
        mkdir -p "$DCONF_DB_DIR"
    fi

    # Apply automount settings if needed
    if [ "$GDM_DA_AUTOMOUNT_OK" -eq 0 ] || [ "$GDM_DA_AUTOMOUNT_OPEN_OK" -eq 0 ]; then
        local l_kfile="$DCONF_DB_DIR/00-media-automount"
        info "Configuring automount settings in $l_kfile"

        if [ -f "$l_kfile" ]; then
            # Remove any existing automount settings to avoid duplicates
            sed -i '/^\s*automount\s*=/d' "$l_kfile"
            sed -i '/^\s*automount-open\s*=/d' "$l_kfile"
        else
            # Create file with section header if it doesn't exist
            echo "[org/gnome/desktop/media-handling]" >"$l_kfile"
        fi

        # Add the section header if it doesn't exist
        if ! grep -q '^\[org/gnome/desktop/media-handling\]' "$l_kfile"; then
            echo "[org/gnome/desktop/media-handling]" >>"$l_kfile"
        fi

        # Add the correct settings
        sed -i '/^\[org\/gnome\/desktop\/media-handling\]/a automount=false' "$l_kfile"
        sed -i '/^\[org\/gnome\/desktop\/media-handling\]/a automount-open=false' "$l_kfile"
    fi

    # Update dconf database
    if command -v dconf >/dev/null 2>&1; then
        info "Updating dconf database"
        dconf update
    fi
}

# This function will check config parameters required
check_config() {
    :
}

# Source Root Dir Parameter
if [ -r /etc/default/cis-hardening ]; then
    # shellcheck source=../../debian/default
    . /etc/default/cis-hardening
fi
if [ -z "${CIS_LIB_DIR}" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_LIB_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r "${CIS_LIB_DIR}"/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "${CIS_LIB_DIR}"/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is ${CIS_LIB_DIR} in /etc/default/cis-hardening"
    exit 128
fi
