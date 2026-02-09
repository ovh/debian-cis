#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure GDM disabling of automount is not overridden (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure GDM disabling of automount is not overridden."

PACKAGE='gdm3'
DCONF_PROFILE_DIR='/etc/dconf/profile'
DCONF_DB_DIR='/etc/dconf/db/local.d'
DCONF_LOCK_DIR='/etc/dconf/db/local.d/locks'
USER_PROFILE_FILE="$DCONF_PROFILE_DIR/user"
AUTOMOUNT_CONF_FILE="$DCONF_DB_DIR/00-media-automount"
AUTOMOUNT_LOCK_FILE="$DCONF_LOCK_DIR/media-automount"

# Global state
GDM_INSTALLED=1
PROFILE_OK=1
SETTINGS_OK=1
LOCKS_OK=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    GDM_INSTALLED=1
    PROFILE_OK=1
    SETTINGS_OK=1
    LOCKS_OK=1

    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        ok "$PACKAGE is not installed, automount settings not applicable"
        GDM_INSTALLED=0
        return
    fi
    ok "$PACKAGE is installed"

    # Check profile file
    if [ ! -f "$USER_PROFILE_FILE" ]; then
        crit "DConf user profile file $USER_PROFILE_FILE does not exist"
        PROFILE_OK=0
    else
        does_pattern_exist_in_file "$USER_PROFILE_FILE" "user-db:user"
        if [ "$FNRET" != 0 ]; then
            crit "DConf user profile missing 'user-db:user' directive"
            PROFILE_OK=0
        else
            does_pattern_exist_in_file "$USER_PROFILE_FILE" "system-db:local"
            if [ "$FNRET" != 0 ]; then
                crit "DConf user profile missing 'system-db:local' directive"
                PROFILE_OK=0
            else
                ok "DConf user profile correctly configured"
            fi
        fi
    fi

    # Check automount settings
    if [ ! -f "$AUTOMOUNT_CONF_FILE" ]; then
        crit "Automount configuration file $AUTOMOUNT_CONF_FILE does not exist"
        SETTINGS_OK=0
    else
        does_pattern_exist_in_file "$AUTOMOUNT_CONF_FILE" "automount=false"
        if [ "$FNRET" != 0 ]; then
            crit "automount not set to false in $AUTOMOUNT_CONF_FILE"
            SETTINGS_OK=0
        else
            ok "automount correctly set to false"
        fi
        does_pattern_exist_in_file "$AUTOMOUNT_CONF_FILE" "automount-open=false"
        if [ "$FNRET" != 0 ]; then
            crit "automount-open not set to false in $AUTOMOUNT_CONF_FILE"
            SETTINGS_OK=0
        else
            ok "automount-open correctly set to false"
        fi
    fi

    # Check locks
    if [ ! -f "$AUTOMOUNT_LOCK_FILE" ]; then
        crit "Automount lock file $AUTOMOUNT_LOCK_FILE does not exist"
        LOCKS_OK=0
    else
        does_pattern_exist_in_file "$AUTOMOUNT_LOCK_FILE" "/org/gnome/desktop/media-handling/automount"
        if [ "$FNRET" != 0 ]; then
            crit "automount not locked in $AUTOMOUNT_LOCK_FILE"
            LOCKS_OK=0
        else
            ok "automount is locked"
        fi
        does_pattern_exist_in_file "$AUTOMOUNT_LOCK_FILE" "/org/gnome/desktop/media-handling/automount-open"
        if [ "$FNRET" != 0 ]; then
            crit "automount-open not locked in $AUTOMOUNT_LOCK_FILE"
            LOCKS_OK=0
        else
            ok "automount-open is locked"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$GDM_INSTALLED" -eq 0 ]; then
        ok "$PACKAGE is not installed, nothing to apply"
        return
    fi

    # Create profile directory and file
    if [ "$PROFILE_OK" -eq 0 ]; then
        info "Creating/updating DConf user profile"
        mkdir -p "$DCONF_PROFILE_DIR"
        cat >"$USER_PROFILE_FILE" <<EOF
user-db:user
system-db:local
EOF
        PROFILE_OK=1
    fi

    # Create automount settings
    if [ "$SETTINGS_OK" -eq 0 ]; then
        info "Creating automount configuration"
        mkdir -p "$DCONF_DB_DIR"
        cat >"$AUTOMOUNT_CONF_FILE" <<EOF
[org/gnome/desktop/media-handling]
automount=false
automount-open=false
EOF
        SETTINGS_OK=1
    fi

    # Create locks
    if [ "$LOCKS_OK" -eq 0 ]; then
        info "Creating automount locks"
        mkdir -p "$DCONF_LOCK_DIR"
        cat >"$AUTOMOUNT_LOCK_FILE" <<EOF
/org/gnome/desktop/media-handling/automount
/org/gnome/desktop/media-handling/automount-open
EOF
        LOCKS_OK=1
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
