#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure journald service is enabled and active (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure journald service is enabled and active"
SERVICE="systemd-journald.service"

# This function will be called if the script status is on enabled / audit mode
audit() {
    SERVICE_ENABLED=1
    SERVICE_ACTIVE=1

    is_service_enabled "$SERVICE"
    if [ "$FNRET" -eq 0 ]; then
        ok "$SERVICE is enabled"
        SERVICE_ENABLED=0
    else
        crit "$SERVICE is not enabled"
    fi

    is_service_active "$SERVICE"
    if [ "$FNRET" -eq 0 ]; then
        ok "$SERVICE is active"
        SERVICE_ACTIVE=0
    else
        crit "$SERVICE is not active"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$SERVICE_ENABLED" -ne 0 ]; then
        info "unmasking and enabling $SERVICE"
        manage_service unmask "$SERVICE"
        manage_service enable "$SERVICE"
    fi

    if [ "$SERVICE_ACTIVE" -ne 0 ]; then
        info "starting $SERVICE"
        manage_service start "$SERVICE"
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
