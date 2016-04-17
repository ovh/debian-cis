#!/bin/bash

#
# CIS Debian 7 Hardening
# Authors : Thibault Dewailly, OVH <thibault.dewailly@corp.ovh.com>
#

#
# 13.20 Ensure shadow group is empty (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

ERRORS=0
FILEGROUP='/etc/group'
PATTERN='^shadow:x:[[:digit:]]+:'

# This function will be called if the script status is on enabled / audit mode
audit () {
    does_pattern_exists_in_file $FILEGROUP $PATTERN
    if [ $FNRET = 0 ]; then
        info "shadow group exists"
        RESULT=$(grep -E "$PATTERN" $FILEGROUP | cut -d: -f4)
        GROUPID=$(getent group shadow | cut -d: -f3)
        debug "$RESULT $GROUPID"
        if [ ! -z "$RESULT" ]; then
            crit "Some user belong to shadow group  : $RESULT"
        else
            ok "No one belongs to shadow group"
        fi

        info "Checking if a user has $GROUPID as primary group"
        RESULT=$(awk -F: '($4 == shadowid) { print $1 }' shadowid=$GROUPID /etc/passwd)
        if [ ! -z "$RESULT" ]; then
            crit "Some user have shadow id to their primary group : $RESULT"
        else
            ok "No one have shadow id to their primary group"
        fi
    else
        crit "shadow group doesn't exist"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    info "If the audit returns something, please check with the user why he has this file"
}

# This function will check config parameters required
check_config() {
    :
}

# Source Root Dir Parameter
if [ ! -r /etc/default/cis-hardenning ]; then
    echo "There is no /etc/default/cis-hardenning FILE, cannot source CIS_ROOT_DIR variable, aborting"
    exit 128
else
    . /etc/default/cis-hardenning
    if [ -z $CIS_ROOT_DIR ]; then
        echo "No CIS_ROOT_DIR variable, aborting"
    fi
fi 

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
[ -r $CIS_ROOT_DIR/lib/main.sh ] && . $CIS_ROOT_DIR/lib/main.sh
