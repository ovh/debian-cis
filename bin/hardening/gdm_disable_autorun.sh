#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure GDM autorun-never is enabled (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Ensure GDM autorun-never is enabled."

PACKAGES='gdm gdm3'
DCONF_PROFILE_DIR='/etc/dconf/profile'
DCONF_DB_BASE_DIR='/etc/dconf/db'

# Global state
GDM_AR_INSTALLED=0
GDM_AR_PROFILE_NAME=""
GDM_AR_PROFILE_FILE=""
GDM_AR_KEYFILE=""
GDM_AR_GPDIR=""
GDM_AR_DBFILE=""
GDM_AR_PROFILE_EXISTS=0
GDM_AR_DB_EXISTS=0
GDM_AR_DIR_EXISTS=0
GDM_AR_SETTING_OK=0

# This function will be called if the script status is on enabled / audit mode
audit() {
    # Check if GNOME Desktop Manager is installed
    for l_package in $PACKAGES; do
        is_pkg_installed "$l_package"
        if [ "$FNRET" = 0 ]; then
            ok "Package $l_package is installed"
            GDM_AR_INSTALLED=1
            break
        fi
    done

    if [ "$GDM_AR_INSTALLED" -eq 0 ]; then
        ok "GNOME Desktop Manager package is not installed on the system - Recommendation is not applicable"
        return
    fi

    # Look for existing settings and set variables if they exist
    GDM_AR_KEYFILE="$(grep -Prils -- '^\h*autorun-never\b' $DCONF_DB_BASE_DIR/*.d 2>/dev/null || true)"

    # Set profile name based on dconf db directory ({PROFILE_NAME}.d)
    if [ -n "$GDM_AR_KEYFILE" ]; then
        GDM_AR_PROFILE_NAME="$(awk -F/ '{split($(NF-1),a,".");print a[1]}' <<<"$GDM_AR_KEYFILE")"
    fi

    # If the profile name exists, continue checks
    if [ -n "$GDM_AR_PROFILE_NAME" ]; then
        GDM_AR_GPDIR="$DCONF_DB_BASE_DIR/$GDM_AR_PROFILE_NAME.d"
        GDM_AR_DBFILE="$DCONF_DB_BASE_DIR/$GDM_AR_PROFILE_NAME"

        # Check if profile file exists
        GDM_AR_PROFILE_FILE="$(grep -Pl -- "^\h*system-db:$GDM_AR_PROFILE_NAME\b" $DCONF_PROFILE_DIR/* 2>/dev/null || true)"
        if [ -n "$GDM_AR_PROFILE_FILE" ]; then
            ok "dconf database profile file $GDM_AR_PROFILE_FILE exists"
            GDM_AR_PROFILE_EXISTS=1
        else
            crit "dconf database profile isn't set for $GDM_AR_PROFILE_NAME"
            GDM_AR_PROFILE_EXISTS=0
        fi

        # Check if the dconf database file exists
        if [ -f "$GDM_AR_DBFILE" ]; then
            ok "The dconf database $GDM_AR_PROFILE_NAME exists"
            # shellcheck disable=2034
            GDM_AR_DB_EXISTS=1
        else
            crit "The dconf database $GDM_AR_PROFILE_NAME doesn't exist"
            # shellcheck disable=2034
            GDM_AR_DB_EXISTS=0
        fi

        # Check if the dconf database directory exists
        if [ -d "$GDM_AR_GPDIR" ]; then
            ok "The dconf directory $GDM_AR_GPDIR exists"
            GDM_AR_DIR_EXISTS=1
        else
            crit "The dconf directory $GDM_AR_GPDIR doesn't exist"
            GDM_AR_DIR_EXISTS=0
        fi

        # Check autorun-never setting
        if grep -Pqrs -- '^\h*autorun-never\h*=\h*true\b' "$GDM_AR_KEYFILE"; then
            ok "autorun-never is set to true in: $GDM_AR_KEYFILE"
            GDM_AR_SETTING_OK=1
        else
            crit "autorun-never is not set correctly"
            GDM_AR_SETTING_OK=0
        fi
    else
        # Settings don't exist. Nothing further to check
        crit "autorun-never is not set"
        GDM_AR_SETTING_OK=0
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$GDM_AR_INSTALLED" -eq 0 ]; then
        ok "GNOME Desktop Manager is not installed, nothing to apply"
        return
    fi

    # Use global variables set by audit() to determine what to fix
    local l_gpname="${GDM_AR_PROFILE_NAME:-local}" # Use detected profile or default to "local"
    local l_kfile="${GDM_AR_KEYFILE}"

    # If no existing keyfile, set default path
    if [ -z "$l_kfile" ]; then
        l_kfile="$DCONF_DB_BASE_DIR/$l_gpname.d/00-media-autorun"
    fi

    # Create profile file if it doesn't exist
    if [ "$GDM_AR_PROFILE_EXISTS" -eq 0 ]; then
        local l_gpfile="$DCONF_PROFILE_DIR/user"
        if [ -f "$l_gpfile" ] && ! grep -Pq -- "^\h*system-db:$l_gpname\b" "$l_gpfile" 2>/dev/null; then
            l_gpfile="$DCONF_PROFILE_DIR/user2"
        fi
        info "Creating dconf database profile: $l_gpfile"
        mkdir -p "$DCONF_PROFILE_DIR"
        {
            echo ""
            echo "user-db:user"
            echo "system-db:$l_gpname"
        } >>"$l_gpfile"
    fi

    # Create dconf directory if it doesn't exist
    if [ "$GDM_AR_DIR_EXISTS" -eq 0 ]; then
        local l_gpdir="$DCONF_DB_BASE_DIR/$l_gpname.d"
        info "Creating dconf database directory $l_gpdir"
        mkdir -p "$l_gpdir"
    fi

    # Set autorun-never setting if not correct
    if [ "$GDM_AR_SETTING_OK" -eq 0 ]; then
        info "Setting autorun-never to true in: $l_kfile"
        if [ -f "$l_kfile" ]; then
            # Remove any existing autorun-never lines to avoid duplicates
            sed -i '/^\s*autorun-never\s*=/d' "$l_kfile"
        else
            # Create file with section header if it doesn't exist
            echo "[org/gnome/desktop/media-handling]" >"$l_kfile"
        fi
        # Add the correct setting
        if ! grep -q '^\[org/gnome/desktop/media-handling\]' "$l_kfile"; then
            echo "[org/gnome/desktop/media-handling]" >>"$l_kfile"
        fi
        sed -i '/^\[org\/gnome\/desktop\/media-handling\]/a autorun-never=true' "$l_kfile"
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
