#!/bin/bash

#
# CIS Debian 7/8 Hardening
#

#
# 12.11 Find SGID System Executables (Not Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# This function will be called if the script status is on enabled / audit mode
audit () {
    info "Checking if there are sgid files"
    RESULT=$(df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -type f -perm -2000 -print)
    for BINARY in $RESULT; do
        if grep -q $BINARY <<< "$EXCEPTIONS"; then
            debug "$BINARY is confirmed as an exception"
            RESULT=$(sed "s!$BINARY!!" <<< $RESULT)
        fi
    done
    if [ ! -z "$RESULT" ]; then
        crit "Some sgid files are present"
        FORMATTED_RESULT=$(sed "s/ /\n/g" <<< $RESULT | sort | uniq | tr '\n' ' ')
        crit "$FORMATTED_RESULT"
    else
        ok "No unknown sgid files found"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    info "Removing sgid on valid binary may seriously harm your system, report only here"
}

# This function will check config parameters required
check_config() {
    if [ -z "$EXCEPTIONS" ]; then
        EXCEPTIONS="@"
    fi
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
