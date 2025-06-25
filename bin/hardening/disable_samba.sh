#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure Samba is not enabled (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure Samba is not enabled."
# shellcheck disable=2034
HARDENING_EXCEPTION=samba

PACKAGES='samba'
SERVICE='smbd'

# This function will be called if the script status is on enabled / audit mode
audit() {
    for PACKAGE in $PACKAGES; do
        is_pkg_installed "$PACKAGE"
        if [ "$FNRET" = 0 ]; then
            crit "$PACKAGE is installed!"
        else
            ok "$PACKAGE is absent"
        fi
    done
    is_service_enabled "$SERVICE"
    if [ "$FNRET" = 0 ]; then
        crit "Service $SERVICE is enabled!"
    else
        ok "Service $SERVICE is disabled"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    for PACKAGE in $PACKAGES; do
        is_pkg_installed "$PACKAGE"
        if [ "$FNRET" = 0 ]; then
            crit "$PACKAGE is installed, purging it"
            apt-get purge "$PACKAGE" -y
            apt-get autoremove -y
        else
            ok "$PACKAGE is absent"
        fi
    done
    is_service_enabled "$SERVICE"
    if [ "$FNRET" = 0 ]; then
        crit "Service $SERVICE is enabled!"
        systemctl disable "$SERVICE"
    else
        ok "Service $SERVICE is disabled"
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
