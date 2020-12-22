#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 4.1.1.2 Ensure auditd service is enabled (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=4
# shellcheck disable=2034
DESCRIPTION="Ensure auditd service is installed and running."

PACKAGE='auditd'
SERVICE_NAME='auditd'

# This function will be called if the script status is on enabled / audit mode
audit() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        crit "$PACKAGE is not installed!"
    else
        ok "$PACKAGE is installed"
        is_service_enabled "$SERVICE_NAME"
        if [ "$FNRET" = 0 ]; then
            ok "$SERVICE_NAME is enabled"
        else
            crit "$SERVICE_NAME is not enabled"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" = 0 ]; then
        ok "$PACKAGE is installed"
    else
        warn "$PACKAGE is absent, installing it"
        apt_install "$PACKAGE"
    fi
    is_service_enabled "$SERVICE_NAME"
    if [ "$FNRET" = 0 ]; then
        ok "$SERVICE_NAME is enabled"
    else
        warn "$SERVICE_NAME is not enabled, enabling it"
        update-rc.d "$SERVICE_NAME" remove >/dev/null 2>&1
        update-rc.d "$SERVICE_NAME" defaults >/dev/null 2>&1
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
if [ -z "$CIS_ROOT_DIR" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_ROOT_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r "$CIS_ROOT_DIR"/lib/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "$CIS_ROOT_DIR"/lib/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_ROOT_DIR in /etc/default/cis-hardening"
    exit 128
fi
