#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 4.2.2.1 Ensure syslog-ng service is enabled (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

HARDENING_LEVEL=3
DESCRIPTION="Ensure syslog-ng service is activated."

SERVICE_NAME="syslog-ng"

# This function will be called if the script status is on enabled / audit mode
audit () {
    info "Checking if $SERVICE_NAME is enabled"
    is_service_enabled $SERVICE_NAME
    if [ $FNRET = 0 ]; then
        ok "$SERVICE_NAME is enabled"
    else
        crit "$SERVICE_NAME is disabled"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    info "Checking if $SERVICE_NAME is enabled"
    is_service_enabled $SERVICE_NAME
    if [ $FNRET != 0 ]; then
        info "Enabling $SERVICE_NAME"
        update-rc.d $SERVICE_NAME remove > /dev/null 2>&1
        update-rc.d $SERVICE_NAME defaults > /dev/null 2>&1
    else
        ok "$SERVICE_NAME is enabled"
    fi
}

# This function will check config parameters required
check_config() {
    :
}

# Source Root Dir Parameter
if [ -r /etc/default/cis-hardening ]; then
    . /etc/default/cis-hardening
fi
if [ -z "$CIS_ROOT_DIR" ]; then
     echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
     echo "Cannot source CIS_ROOT_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r $CIS_ROOT_DIR/lib/main.sh ]; then
    . $CIS_ROOT_DIR/lib/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_ROOT_DIR in /etc/default/cis-hardening"
    exit 128
fi
