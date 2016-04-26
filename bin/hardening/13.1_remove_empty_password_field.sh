#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 13.1 Ensure Password Fields are Not Empty (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

FILE='/etc/shadow'

# This function will be called if the script status is on enabled / audit mode
audit () {
    info "Checking if accounts have an empty password"
    RESULT=$(cat $FILE | awk -F: '($2 == "" ) { print $1 }')
    if [ ! -z "$RESULT" ]; then
        crit "Some accounts have an empty password"
        crit $RESULT
    else
        ok "All accounts have a password"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    RESULT=$(cat $FILE | awk -F: '($2 == "" ) { print $1 }')
    if [ ! -z "$RESULT" ]; then
        warn "Some accounts have an empty password"
        for ACCOUNT in $RESULT; do
            info "Locking $ACCOUNT"
            passwd -l $ACCOUNT >/dev/null 2>&1
        done
    else
        ok "All accounts have a password"
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
