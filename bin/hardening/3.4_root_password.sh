#!/bin/bash

#
# CIS Debian 7 Hardening
# Authors : Thibault Dewailly, OVH <thibault.dewailly@corp.ovh.com>
#

#
# 3.4 Require Authentication for Single-User Mode (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

FILE="/etc/shadow"
PATTERN="^root:[*\!]:"

# This function will be called if the script status is on enabled / audit mode
audit () {
    does_pattern_exists_in_file $FILE $PATTERN
    if [ $FNRET != 1 ]; then
        crit "$PATTERN present in $FILE"
    else
        ok "$PATTERN not present in $FILE"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    does_pattern_exists_in_file $FILE $PATTERN
    if [ $FNRET != 1 ]; then
        warn "$PATTERN present in $FILE, please put a root password"
    else
        ok "$PATTERN not present in $FILE"
    fi
    :
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
