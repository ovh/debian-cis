#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

set -e
set -u

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Ensure screen locks when the user is idle (lock-delay <= 5s, idle-delay <= 900s and not 0)"

# Global variables with unique prefix
GNOME_LOCK_PACKAGE="gnome-shell"
GNOME_LOCK_DCONF_DB="local"
GNOME_LOCK_PROFILE_DIR="/etc/dconf/profile"
GNOME_LOCK_PROFILE_FILE="${GNOME_LOCK_PROFILE_DIR}/user"
GNOME_LOCK_DB_DIR="/etc/dconf/db/${GNOME_LOCK_DCONF_DB}.d"
GNOME_LOCK_SETTINGS_FILE="${GNOME_LOCK_DB_DIR}/00-screensaver"
# shellcheck disable=2034
GNOME_LOCK_MAX_LOCK_DELAY=5
# shellcheck disable=2034
GNOME_LOCK_MAX_IDLE_DELAY=900
# Global variables to store audit state
GNOME_LOCK_PKG_INSTALLED=1
GNOME_LOCK_PROFILE_EXISTS=1
GNOME_LOCK_PROFILE_HAS_USER_DB=1
GNOME_LOCK_PROFILE_HAS_SYSTEM_DB=1
GNOME_LOCK_SETTINGS_EXISTS=1
GNOME_LOCK_SETTINGS_HAS_SECTION=1
GNOME_LOCK_SETTINGS_HAS_IDLE_ENABLED=1
GNOME_LOCK_SETTINGS_HAS_LOCK_ENABLED=1

audit() {
    is_pkg_installed "$GNOME_LOCK_PACKAGE"
    GNOME_LOCK_PKG_INSTALLED=$FNRET
    if [ "$GNOME_LOCK_PKG_INSTALLED" -ne 0 ]; then
        ok "$GNOME_LOCK_PACKAGE is not installed"
        return
    fi

    # Check profile file
    does_file_exist "$GNOME_LOCK_PROFILE_FILE"
    GNOME_LOCK_PROFILE_EXISTS=$FNRET
    if [ "$GNOME_LOCK_PROFILE_EXISTS" -ne 0 ]; then
        crit "$GNOME_LOCK_PROFILE_FILE does not exist"
        return
    fi

    does_pattern_exist_in_file "$GNOME_LOCK_PROFILE_FILE" "^user-db:user$"
    GNOME_LOCK_PROFILE_HAS_USER_DB=$FNRET
    if [ "$GNOME_LOCK_PROFILE_HAS_USER_DB" -ne 0 ]; then
        crit "$GNOME_LOCK_PROFILE_FILE missing user-db:user"
        return
    fi

    does_pattern_exist_in_file "$GNOME_LOCK_PROFILE_FILE" "^system-db:${GNOME_LOCK_DCONF_DB}$"
    GNOME_LOCK_PROFILE_HAS_SYSTEM_DB=$FNRET
    if [ "$GNOME_LOCK_PROFILE_HAS_SYSTEM_DB" -ne 0 ]; then
        crit "$GNOME_LOCK_PROFILE_FILE missing system-db:${GNOME_LOCK_DCONF_DB}"
        return
    fi

    # Check settings file
    does_file_exist "$GNOME_LOCK_SETTINGS_FILE"
    GNOME_LOCK_SETTINGS_EXISTS=$FNRET
    if [ "$GNOME_LOCK_SETTINGS_EXISTS" -ne 0 ]; then
        crit "$GNOME_LOCK_SETTINGS_FILE does not exist"
        return
    fi

    does_pattern_exist_in_file "$GNOME_LOCK_SETTINGS_FILE" "^\[org/gnome/desktop/screensaver\]$"
    GNOME_LOCK_SETTINGS_HAS_SECTION=$FNRET
    if [ "$GNOME_LOCK_SETTINGS_HAS_SECTION" -ne 0 ]; then
        crit "$GNOME_LOCK_SETTINGS_FILE missing screensaver section"
        return
    fi

    does_pattern_exist_in_file "$GNOME_LOCK_SETTINGS_FILE" "^idle-activation-enabled=true$"
    GNOME_LOCK_SETTINGS_HAS_IDLE_ENABLED=$FNRET
    if [ "$GNOME_LOCK_SETTINGS_HAS_IDLE_ENABLED" -ne 0 ]; then
        crit "$GNOME_LOCK_SETTINGS_FILE missing or incorrect idle-activation-enabled"
        return
    fi

    does_pattern_exist_in_file "$GNOME_LOCK_SETTINGS_FILE" "^lock-enabled=true$"
    GNOME_LOCK_SETTINGS_HAS_LOCK_ENABLED=$FNRET
    if [ "$GNOME_LOCK_SETTINGS_HAS_LOCK_ENABLED" -ne 0 ]; then
        crit "$GNOME_LOCK_SETTINGS_FILE missing or incorrect lock-enabled"
        return
    fi

    ok "GNOME screensaver idle lock is correctly configured"
}

apply() {
    if [ "$GNOME_LOCK_PKG_INSTALLED" -ne 0 ]; then
        ok "$GNOME_LOCK_PACKAGE is not installed (nothing to apply)"
        return
    fi

    # Create profile directory and file
    if [ ! -d "$GNOME_LOCK_PROFILE_DIR" ]; then
        info "Creating $GNOME_LOCK_PROFILE_DIR"
        mkdir -p "$GNOME_LOCK_PROFILE_DIR"
    fi

    if [ "$GNOME_LOCK_PROFILE_EXISTS" -ne 0 ]; then
        info "Creating $GNOME_LOCK_PROFILE_FILE"
        cat >"$GNOME_LOCK_PROFILE_FILE" <<EOF
user-db:user
system-db:${GNOME_LOCK_DCONF_DB}
EOF
    else
        if [ "$GNOME_LOCK_PROFILE_HAS_USER_DB" -ne 0 ]; then
            info "Setting user-db:user in $GNOME_LOCK_PROFILE_FILE"
            backup_file "$GNOME_LOCK_PROFILE_FILE"
            sed -i '/^user-db:/d' "$GNOME_LOCK_PROFILE_FILE"
            echo "user-db:user" >>"$GNOME_LOCK_PROFILE_FILE"
        fi

        if [ "$GNOME_LOCK_PROFILE_HAS_SYSTEM_DB" -ne 0 ]; then
            info "Setting system-db:${GNOME_LOCK_DCONF_DB} in $GNOME_LOCK_PROFILE_FILE"
            if [ "$GNOME_LOCK_PROFILE_HAS_USER_DB" -eq 0 ]; then
                backup_file "$GNOME_LOCK_PROFILE_FILE"
            fi
            sed -i '/^system-db:/d' "$GNOME_LOCK_PROFILE_FILE"
            echo "system-db:${GNOME_LOCK_DCONF_DB}" >>"$GNOME_LOCK_PROFILE_FILE"
        fi
    fi

    # Create settings directory and file
    if [ ! -d "$GNOME_LOCK_DB_DIR" ]; then
        info "Creating $GNOME_LOCK_DB_DIR"
        mkdir -p "$GNOME_LOCK_DB_DIR"
    fi

    if [ "$GNOME_LOCK_SETTINGS_EXISTS" -ne 0 ]; then
        info "Creating $GNOME_LOCK_SETTINGS_FILE"
        cat >"$GNOME_LOCK_SETTINGS_FILE" <<EOF
[org/gnome/desktop/screensaver]
idle-activation-enabled=true
lock-enabled=true
EOF
    else
        backup_file "$GNOME_LOCK_SETTINGS_FILE"

        if [ "$GNOME_LOCK_SETTINGS_HAS_SECTION" -ne 0 ]; then
            info "Adding screensaver section to $GNOME_LOCK_SETTINGS_FILE"
            echo "[org/gnome/desktop/screensaver]" >>"$GNOME_LOCK_SETTINGS_FILE"
        fi

        if [ "$GNOME_LOCK_SETTINGS_HAS_IDLE_ENABLED" -ne 0 ]; then
            info "Setting idle-activation-enabled=true"
            sed -i '/^\[org\/gnome\/desktop\/screensaver\]/a idle-activation-enabled=true' "$GNOME_LOCK_SETTINGS_FILE"
        fi

        if [ "$GNOME_LOCK_SETTINGS_HAS_LOCK_ENABLED" -ne 0 ]; then
            info "Setting lock-enabled=true"
            sed -i '/^\[org\/gnome\/desktop\/screensaver\]/a lock-enabled=true' "$GNOME_LOCK_SETTINGS_FILE"
        fi
    fi

    # Update dconf database
    info "Updating dconf database"
    dconf update

    ok "GNOME screensaver idle lock configuration applied"
}

check_config() {
    :
}

# Source Root Dir Parameter
if [ -r /etc/default/cis-hardening ]; then
    # shellcheck source=../../debian/default
    . /etc/default/cis-hardening
fi

if [ -z "${CIS_LIB_DIR:-}" ]; then
    echo "There is no /etc/default/cis-hardening file nor CIS_LIB_DIR in environment."
    exit 128
fi

# Main function
if [ -r "${CIS_LIB_DIR}/main.sh" ]; then
    # shellcheck source=../../lib/main.sh
    . "${CIS_LIB_DIR}/main.sh"
else
    echo "Cannot find main.sh in CIS_LIB_DIR=${CIS_LIB_DIR}"
    exit 128
fi
