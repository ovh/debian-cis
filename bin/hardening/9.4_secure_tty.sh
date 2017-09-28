#!/bin/bash

#
# CIS Debian 7/8 Hardening
#

#
# 9.4 Restrict root Login to System Console (Not Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

HARDENING_LEVEL=3

FILE='/etc/securetty'

# This function will be called if the script status is on enabled / audit mode
audit () {
    info "Remove terminal entries in $FILE for any consoles that are not in a physically secure location."
    info "No measure here, please review the file by yourself"
}

# This function will be called if the script status is on enabled mode
apply () {
    info "Remove terminal entries in $FILE for any consoles that are not in a physically secure location."
    info "No measure here, please review the file by yourself"
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
    if [ -z ${CIS_ROOT_DIR:-} ]; then
        echo "No CIS_ROOT_DIR variable, aborting"
        exit 128
    fi
fi 

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r $CIS_ROOT_DIR/lib/main.sh ]; then
    . $CIS_ROOT_DIR/lib/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_ROOT_DIR in /etc/default/cis-hardening"
    exit 128
fi
