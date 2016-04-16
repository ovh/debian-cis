#!/bin/bash

#
# CIS Debian 7 Hardening
# Authors : Thibault Dewailly, OVH <thibault.dewailly@corp.ovh.com>
#

#
# 13.2 Verify No Legacy "+" Entries Exist in /etc/passwd File (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

FILE='/etc/passwd'
RESULT=''

# This function will be called if the script status is on enabled / audit mode
audit () {
    info "Checking if accounts have empty passwords"
    if grep '^+:' $FILE -q; then
        RESULT=$(grep '^+:' $FILE)
        crit "Some accounts have legacy password entry"
        crit $RESULT
    else
        ok "All accounts have a valid password entry format"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    if grep '^+:' $FILE -q; then
        RESULT=$(grep '^+:' $FILE)
        warn "Some accounts have legacy password entry"
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
