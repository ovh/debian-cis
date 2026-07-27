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

PACKAGES='gdm gdm3'
GDM_CONFIG_FILES=""

# Global state
GDM_XDMCP_INSTALLED=0
GDM_XDMCP_ENABLED=0

# This function will be called if the script status is on enabled / audit mode
audit() {
    for l_package in $PACKAGES; do
        is_pkg_installed "$l_package"
        if [ "$FNRET" = 0 ]; then
            ok "Package $l_package is installed"
            GDM_XDMCP_INSTALLED=1
            if [ "$l_package" = "gdm3" ]; then
                GDM_CONFIG_FILES="/etc/gdm3/custom.conf /etc/gdm3/daemon.conf"
            else
                GDM_CONFIG_FILES="/etc/gdm/custom.conf /etc/gdm/daemon.conf"
            fi
            break
        fi
    done

    if [ "$GDM_XDMCP_INSTALLED" -eq 0 ]; then
        ok "GNOME Desktop Manager package is not installed, XDMCP not applicable"
        return
    fi

    for CONFIG_FILE in $GDM_CONFIG_FILES; do
        if [ -f "$CONFIG_FILE" ]; then
            # Check if XDMCP is explicitly enabled in [xdmcp] section
            # Use awk to parse INI file and check only within [xdmcp] section
            if awk '/^\[xdmcp\]/ {in_section=1} /^\[/ && !/^\[xdmcp\]/ {in_section=0} in_section && /^[[:space:]]*Enable[[:space:]]*=[[:space:]]*true/ {found=1; exit} END {exit !found}' "$CONFIG_FILE"; then
                crit "XDMCP is enabled in $CONFIG_FILE"
                GDM_XDMCP_ENABLED=1
            fi
        fi
    done

    if [ "$GDM_XDMCP_ENABLED" -eq 0 ]; then
        ok "XDMCP is not enabled in GDM configuration"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$GDM_XDMCP_INSTALLED" -eq 0 ]; then
        ok "GNOME Desktop Manager is not installed, nothing to apply"
        return
    fi

    if [ "$GDM_XDMCP_ENABLED" -eq 1 ]; then
        for CONFIG_FILE in $GDM_CONFIG_FILES; do
            if [ -f "$CONFIG_FILE" ]; then
                # Comment out Enable=true lines only in the [xdmcp] section
                info "Disabling XDMCP in $CONFIG_FILE"
                backup_file "$CONFIG_FILE"
                # Use awk to comment out Enable=true only within [xdmcp] section
                awk '/^\[xdmcp\]/ {in_section=1} /^\[/ && !/^\[xdmcp\]/ {in_section=0} in_section && /^[[:space:]]*Enable[[:space:]]*=[[:space:]]*true/ {gsub(/^[[:space:]]*Enable/, "#Enable"); print; next} {print}' "$CONFIG_FILE" >"${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
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
