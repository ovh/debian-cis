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
DESCRIPTION="Ensure GDM disable-user-list option is enabled"

# Global variables with unique prefix
GDM_USER_LIST_PACKAGE="gdm3"
GDM_USER_LIST_CONFIG="/etc/gdm3/greeter.dconf-defaults"
GDM_USER_LIST_KEY="disable-user-list"
GDM_USER_LIST_VALUE="true"
# Global variables to store audit state
GDM_USER_LIST_PKG_INSTALLED=1
GDM_USER_LIST_CONFIG_EXISTS=1
GDM_USER_LIST_SETTING_CORRECT=1

audit() {
    is_pkg_installed "$GDM_USER_LIST_PACKAGE"
    GDM_USER_LIST_PKG_INSTALLED=$FNRET
    if [ "$GDM_USER_LIST_PKG_INSTALLED" -ne 0 ]; then
        ok "$GDM_USER_LIST_PACKAGE is not installed"
        return
    fi

    does_file_exist "$GDM_USER_LIST_CONFIG"
    GDM_USER_LIST_CONFIG_EXISTS=$FNRET
    if [ "$GDM_USER_LIST_CONFIG_EXISTS" -ne 0 ]; then
        crit "$GDM_USER_LIST_CONFIG does not exist"
        return
    fi

    does_pattern_exist_in_file "$GDM_USER_LIST_CONFIG" "^[[:space:]]*${GDM_USER_LIST_KEY}[[:space:]]*=[[:space:]]*${GDM_USER_LIST_VALUE}"
    GDM_USER_LIST_SETTING_CORRECT=$FNRET
    if [ "$GDM_USER_LIST_SETTING_CORRECT" -ne 0 ]; then
        crit "$GDM_USER_LIST_KEY is not set to $GDM_USER_LIST_VALUE in $GDM_USER_LIST_CONFIG"
    else
        ok "$GDM_USER_LIST_KEY is correctly set in $GDM_USER_LIST_CONFIG"
    fi
}

apply() {
    if [ "$GDM_USER_LIST_PKG_INSTALLED" -ne 0 ]; then
        ok "$GDM_USER_LIST_PACKAGE is not installed (nothing to apply)"
        return
    fi

    if [ "$GDM_USER_LIST_CONFIG_EXISTS" -ne 0 ]; then
        warn "$GDM_USER_LIST_CONFIG does not exist, creating it"
        mkdir -p "$(dirname "$GDM_USER_LIST_CONFIG")"
        echo "[org/gnome/login-screen]" >"$GDM_USER_LIST_CONFIG"
        echo "${GDM_USER_LIST_KEY}=${GDM_USER_LIST_VALUE}" >>"$GDM_USER_LIST_CONFIG"
        ok "$GDM_USER_LIST_CONFIG created with correct setting"
        return
    fi

    if [ "$GDM_USER_LIST_SETTING_CORRECT" -ne 0 ]; then
        info "Setting $GDM_USER_LIST_KEY to $GDM_USER_LIST_VALUE in $GDM_USER_LIST_CONFIG"
        backup_file "$GDM_USER_LIST_CONFIG"

        # Check if [org/gnome/login-screen] section exists
        if ! grep -q "^\[org/gnome/login-screen\]" "$GDM_USER_LIST_CONFIG"; then
            echo "[org/gnome/login-screen]" >>"$GDM_USER_LIST_CONFIG"
        fi

        # Remove all instances of the key before adding the correct value
        sed -i "/^[[:space:]]*${GDM_USER_LIST_KEY}/d" "$GDM_USER_LIST_CONFIG"
        sed -i "/^\[org\/gnome\/login-screen\]/a ${GDM_USER_LIST_KEY}=${GDM_USER_LIST_VALUE}" "$GDM_USER_LIST_CONFIG"

        ok "$GDM_USER_LIST_KEY set to $GDM_USER_LIST_VALUE"
    else
        ok "$GDM_USER_LIST_KEY is already correctly configured"
    fi
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
