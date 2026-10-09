#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure GDM login banner is configured (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Set graphical warning banner."

PACKAGES='gdm gdm3'
DCONF_PROFILE_DIR='/etc/dconf/profile'
DCONF_DB_BASE_DIR='/etc/dconf/db'
BANNER_MESSAGE_TEXT="'Authorized uses only. All activity may be monitored and reported'"

GDM_LB_INSTALLED=1
GDM_LB_ERROR_COUNT=0
GDM_LB_PROFILE_NAME=""
GDM_LB_PROFILE_FILE=""
GDM_LB_KEYFILE=""
GDM_LB_DBFILE=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    local l_package
    local l_tmp_keyfile

    GDM_LB_INSTALLED=1
    GDM_LB_ERROR_COUNT=0
    GDM_LB_PROFILE_NAME=""
    GDM_LB_PROFILE_FILE=""
    GDM_LB_KEYFILE=""
    GDM_LB_DBFILE=""

    for l_package in $PACKAGES; do
        is_pkg_installed "$l_package"
        if [ "$FNRET" = 0 ]; then
            ok "Package $l_package is installed"
            GDM_LB_INSTALLED=0
            break
        fi
    done

    if [ "$GDM_LB_INSTALLED" -ne 0 ]; then
        ok "GNOME Desktop Manager is not installed on the system - Recommendation is not applicable"
        return
    fi

    l_tmp_keyfile=$(grep -Prils -- '^\h*banner-message-enable\h*=|^\h*banner-message-text\h*=' "$DCONF_DB_BASE_DIR"/*.d 2>/dev/null | head -n 1 || true)
    GDM_LB_KEYFILE="$l_tmp_keyfile"

    if [ -z "$GDM_LB_KEYFILE" ]; then
        GDM_LB_ERROR_COUNT=$((GDM_LB_ERROR_COUNT + 1))
        crit "banner-message options are not configured in $DCONF_DB_BASE_DIR/*.d"
    else
        GDM_LB_PROFILE_NAME=$(awk -F/ '{split($(NF-1),a,".");print a[1]}' <<<"$GDM_LB_KEYFILE")
        GDM_LB_PROFILE_FILE="$DCONF_PROFILE_DIR/$GDM_LB_PROFILE_NAME"
        GDM_LB_DBFILE="$DCONF_DB_BASE_DIR/$GDM_LB_PROFILE_NAME"

        if grep -Pq -- '^\h*banner-message-enable\h*=\h*true\b' "$GDM_LB_KEYFILE"; then
            ok "banner-message-enable=true is set in $GDM_LB_KEYFILE"
        else
            GDM_LB_ERROR_COUNT=$((GDM_LB_ERROR_COUNT + 1))
            crit "banner-message-enable=true is not set in $GDM_LB_KEYFILE"
        fi

        if grep -Pq -- '^\h*banner-message-text\h*=\h*.+$' "$GDM_LB_KEYFILE"; then
            ok "banner-message-text is set in $GDM_LB_KEYFILE"
        else
            GDM_LB_ERROR_COUNT=$((GDM_LB_ERROR_COUNT + 1))
            crit "banner-message-text is not set in $GDM_LB_KEYFILE"
        fi

        if [ -r "$GDM_LB_PROFILE_FILE" ] && grep -Pq -- "^\h*system-db:$GDM_LB_PROFILE_NAME\b" "$GDM_LB_PROFILE_FILE"; then
            ok "The profile $GDM_LB_PROFILE_FILE exists and references system-db:$GDM_LB_PROFILE_NAME"
        else
            GDM_LB_ERROR_COUNT=$((GDM_LB_ERROR_COUNT + 1))
            crit "The profile $GDM_LB_PROFILE_FILE is missing or does not reference system-db:$GDM_LB_PROFILE_NAME"
        fi

        if [ -f "$GDM_LB_DBFILE" ]; then
            ok "The dconf database file $GDM_LB_DBFILE exists"
        else
            GDM_LB_ERROR_COUNT=$((GDM_LB_ERROR_COUNT + 1))
            crit "The dconf database file $GDM_LB_DBFILE does not exist"
        fi
    fi

    if [ "$GDM_LB_ERROR_COUNT" -eq 0 ]; then
        ok "GDM login banner is configured"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    local l_gpname
    local l_kfile
    local l_profile_file
    local l_db_dir
    local l_db_file

    if [ "$GDM_LB_INSTALLED" -ne 0 ]; then
        ok "GNOME Desktop Manager is not installed on the system - no remediation required"
        return
    fi

    l_gpname="${GDM_LB_PROFILE_NAME:-gdm}"
    l_kfile="${GDM_LB_KEYFILE:-$DCONF_DB_BASE_DIR/$l_gpname.d/01-banner-message}"
    l_profile_file="$DCONF_PROFILE_DIR/$l_gpname"
    l_db_dir="$DCONF_DB_BASE_DIR/$l_gpname.d"
    l_db_file="$DCONF_DB_BASE_DIR/$l_gpname"

    mkdir -p "$DCONF_PROFILE_DIR"
    if [ ! -f "$l_profile_file" ]; then
        info "Creating profile $l_profile_file"
        {
            echo "user-db:user"
            echo "system-db:$l_gpname"
            echo "file-db:/usr/share/$l_gpname/greeter-dconf-defaults"
        } >"$l_profile_file"
    elif ! grep -Pq -- "^\h*system-db:$l_gpname\b" "$l_profile_file"; then
        info "Adding system-db:$l_gpname to $l_profile_file"
        echo "system-db:$l_gpname" >>"$l_profile_file"
    fi

    mkdir -p "$l_db_dir"
    if [ -f "$l_kfile" ]; then
        sed -i '/^\s*banner-message-enable\s*=/d' "$l_kfile"
        sed -i '/^\s*banner-message-text\s*=/d' "$l_kfile"
    else
        echo "[org/gnome/login-screen]" >"$l_kfile"
    fi

    if ! grep -q '^\[org/gnome/login-screen\]' "$l_kfile"; then
        echo "[org/gnome/login-screen]" >>"$l_kfile"
    fi

    sed -i '/^\[org\/gnome\/login-screen\]/a banner-message-enable=true' "$l_kfile"
    sed -i "/^\[org\/gnome\/login-screen\]/a banner-message-text=$BANNER_MESSAGE_TEXT" "$l_kfile"

    if command -v dconf >/dev/null 2>&1; then
        dconf update
    else
        warn "dconf command not found, cannot update dconf database"
    fi

    if [ -f "$l_db_file" ]; then
        ok "GDM login banner has been configured"
    else
        warn "Configuration files were updated, but dconf database file $l_db_file is still missing"
    fi
}

# This function will check config parameters required
check_config() {
    if [ -z "$BANNER_MESSAGE_TEXT" ]; then
        BANNER_MESSAGE_TEXT="'Authorized uses only. All activity may be monitored and reported'"
    fi
}

# Source Root Dir Parameter
if [ -r /etc/default/cis-hardening ]; then
    # shellcheck source=../../debian/default
    . /etc/default/cis-hardening
fi
if [ -z "$CIS_LIB_DIR" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_LIB_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r "${CIS_LIB_DIR}"/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "${CIS_LIB_DIR}"/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_LIB_DIR in /etc/default/cis-hardening"
    exit 128
fi
