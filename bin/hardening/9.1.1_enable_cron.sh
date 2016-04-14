#!/bin/bash

#
# CIS Debian 7 Hardening
# Authors : Thibault Dewailly, OVH <thibault.dewailly@corp.ovh.com>
#

#
# 9.1.1 Enable cron Daemon (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

PACKAGE="cron"
SERVICE_NAME="cron"

# This function will be called if the script status is on enabled / audit mode
audit () {
    is_pkg_installed $PACKAGE
    if [ $FNRET != 0 ]; then
        crit "$PACKAGE is not installed !"
    else
        ok "$PACKAGE is installed"
        is_service_enabled $SERVICE_NAME
        if [ $FNRET = 0 ]; then
            ok "$SERVICE_NAME is enabled"
        else
            crit "$SERVICE_NAME is disabled"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    is_pkg_installed $PACKAGE
    if [ $FNRET = 0 ]; then
        ok "$PACKAGE is installed"
    else
        crit "$PACKAGE is absent, installing it"
        apt_install $PACKAGE
        is_service_enabled $SERVICE_NAME
        if [ $FNRET != 0 ]; then
            info "Enabling $SERVICE_NAME"
            update-rc.d $SERVICE_NAME remove > /dev/null 2>&1
            update-rc.d $SERVICE_NAME defaults > /dev/null 2>&1
        else
            ok "$SERVICE_NAME is enabled"
        fi
    fi 
}

# This function will check config parameters required
check_config() {
    :
}

# Source Root Dir Parameter
if [ ! -r /etc/default/cis-hardenning ]; then
    echo "There is no /etc/default/cis-hardenning file, cannot source CIS_ROOT_DIR variable, aborting"
    exit 128
else
    . /etc/default/cis-hardenning
    if [ -z $CIS_ROOT_DIR ]; then
        echo "No CIS_ROOT_DIR variable, aborting"
    fi
fi 

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
[ -r $CIS_ROOT_DIR/lib/main.sh ] && . $CIS_ROOT_DIR/lib/main.sh
