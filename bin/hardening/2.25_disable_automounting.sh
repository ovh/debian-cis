#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 2.25 Disable Automounting (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

SERVICE_NAME="autofs"

# This function will be called if the script status is on enabled / audit mode
audit () {
    info "Checking if $SERVICE_NAME is enabled"
    is_service_enabled $SERVICE_NAME
    if [ $FNRET = 0 ]; then
        crit "$SERVICE_NAME is enabled"
    else
        ok "$SERVICE_NAME is disabled"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    info "Checking if $SERVICE_NAME is enabled"
    is_service_enabled $SERVICE_NAME
    if [ $FNRET = 0 ]; then
        info "Disabling $SERVICE_NAME"
        update-rc.d $SERVICE_NAME remove > /dev/null 2>&1
    else
        ok "$SERVICE_NAME is disabled"
    fi
}

# This function will check config parameters required
check_config() {
    :
}

# Source Root Dir Parameter
if [ ! -r /etc/default/cis-hardening ]; then
    echo "There is no /etc/default/cis-hardening file, cannot source CIS_ROOT_DIR variable, aborting"
    exit 128
else
    . /etc/default/cis-hardening
    if [ -z $CIS_ROOT_DIR ]; then
        echo "No CIS_ROOT_DIR variable, aborting"
    fi
fi 

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
[ -r $CIS_ROOT_DIR/lib/main.sh ] && . $CIS_ROOT_DIR/lib/main.sh
