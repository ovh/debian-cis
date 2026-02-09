#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure XDMCP is not enabled in GDM (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure XDMCP is not enabled in GDM."

PACKAGE='gdm3'
GDM_CONFIG_FILES="/etc/gdm3/custom.conf /etc/gdm3/daemon.conf /etc/gdm/custom.conf /etc/gdm/daemon.conf"

# Global state
GDM_INSTALLED=1
XDMCP_ENABLED=0

# This function will be called if the script status is on enabled / audit mode
audit() {
    GDM_INSTALLED=1
    XDMCP_ENABLED=0

    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        ok "$PACKAGE is not installed, XDMCP not applicable"
        GDM_INSTALLED=0
        return
    fi
    ok "$PACKAGE is installed"

    for CONFIG_FILE in $GDM_CONFIG_FILES; do
        if [ -f "$CONFIG_FILE" ]; then
            # Check if XDMCP is explicitly enabled
            if grep -Piq '^\s*Enable\s*=\s*true' "$CONFIG_FILE"; then
                crit "XDMCP is enabled in $CONFIG_FILE"
                XDMCP_ENABLED=1
            fi
        fi
    done

    if [ "$XDMCP_ENABLED" -eq 0 ]; then
        ok "XDMCP is not enabled in GDM configuration"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$GDM_INSTALLED" -eq 0 ]; then
        ok "$PACKAGE is not installed, nothing to apply"
        return
    fi

    if [ "$XDMCP_ENABLED" -eq 1 ]; then
        for CONFIG_FILE in $GDM_CONFIG_FILES; do
            if [ -f "$CONFIG_FILE" ]; then
                # Comment out any Enable=true lines in the xdmcp section
                info "Disabling XDMCP in $CONFIG_FILE"
                backup_file "$CONFIG_FILE"
                # Use sed to comment out Enable=true lines that might be in [xdmcp] section
                # This is a simple approach - comment any Enable=true line
                sed -i 's/^\s*Enable\s*=\s*true/#Enable=true/I' "$CONFIG_FILE"
            fi
        done
    else
        ok "XDMCP already disabled"
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
