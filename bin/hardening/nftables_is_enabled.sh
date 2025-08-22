#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure nftables service is enabled (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure nftables service is enabled"
SERVICE="nftables.service"

# This function will be called if the script status is on enabled / audit mode
audit() {
    SERVICE_ENABLED=1

    is_service_enabled "$SERVICE"
    if [ "$FNRET" -eq 0 ]; then
        ok "$SERVICE is enabled"
        SERVICE_ENABLED=0
    else
        crit "$SERVICE is not enabled"
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$SERVICE_ENABLED" -ne 0 ]; then
        manage_service unmask "$SERVICE"
        manage_service enable "$SERVICE"
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
