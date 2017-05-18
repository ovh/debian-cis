#!/bin/bash

#
# CIS Debian 7/8 Hardening
#

#
# 13.3 Verify No Legacy "+" Entries Exist in /etc/shadow File (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

HARDENING_LEVEL=1

FILE='/etc/shadow'
RESULT=''

# This function will be called if the script status is on enabled / audit mode
audit () {
    info "Checking if accounts have a legacy password entry"
    if grep '^+:' $FILE -q; then
        RESULT=$(grep '^+:' $FILE)
        crit "Some accounts have a legacy password entry"
        crit $RESULT
    else
        ok "All accounts have a valid password entry format"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    if grep '^+:' $FILE -q; then
        RESULT=$(grep '^+:' $FILE)
        warn "Some accounts have a legacy password entry"
        for LINE in $RESULT; do
            info "Removing $LINE from $FILE"
            delete_line_in_file $FILE $LINE
        done
    else
        ok "All accounts have a valid password entry format"
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
