#!/bin/bash

#
# CIS Debian 7 Hardening
# Authors : Thibault Dewailly, OVH <thibault.dewailly@corp.ovh.com>
#

#
# 12.10 Find SUID System Executables (Not Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# This function will be called if the script status is on enabled / audit mode
audit () {
    info "Checking if there is suid files"
    RESULT=$(df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -type f -perm -4000 -print)
    for BINARY in $RESULT; do
        if grep -q $BINARY <<< "$EXCEPTIONS"; then
            debug "$BINARY is confirmed as an exception"
            
            RESULT=$(sed '!'"$BINARY"'!d' <<< $RESULT)
        fi
    done
    if [ ! -z "$RESULT" ]; then
        crit "Some world writable file are present"
        FORMATTED_RESULT=$(sed "s/ /\n/g" <<< $RESULT | sort | uniq | tr '\n' ' ')
        crit "$FORMATTED_RESULT"
    else
        ok "No world writable files found"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    info "Removing suid on valid binary may seriously harm your system, report only here"
}

# This function will check config parameters required
check_config() {
    # No param for this function
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
