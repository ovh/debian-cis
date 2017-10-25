#!/bin/bash

#
# CIS Debian 7/8 Hardening
#

#
# 13.16 Check for Duplicate User Names (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

HARDENING_LEVEL=1

ERRORS=0

# This function will be called if the script status is on enabled / audit mode
audit () {
    RESULT=$(cat /etc/passwd | cut -f1 -d":" | sort -n | uniq -c | awk {'print $1":"$2'} )
    for LINE in $RESULT; do 
        debug "Working on line $LINE"
        OCC_NUMBER=$(awk -F: {'print $1'} <<< $LINE)
        USERNAME=$(awk -F: {'print $2'} <<< $LINE) 
        if [ $OCC_NUMBER -gt 1 ]; then
            USERS=$(awk -F: '($3 == n) { print $1 }' n=$USERNAME /etc/passwd | xargs)
            ERRORS=$((ERRORS+1))
            crit "Duplicate username $USERNAME"
        fi
    done 

    if [ $ERRORS = 0 ]; then
        ok "No duplicate usernames"
    fi 
}

# This function will be called if the script status is on enabled mode
apply () {
    info "Editing automatically username may seriously harm your system, report only here"
}

# This function will check config parameters required
check_config() {
    :
}

# Source Root Dir Parameter
if [ -r /etc/default/cis-hardening ]; then
    . /etc/default/cis-hardening
fi
if [ -z "$CIS_ROOT_DIR" ]; then
     echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment." 
     echo "Cannot source CIS_ROOT_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r $CIS_ROOT_DIR/lib/main.sh ]; then
    . $CIS_ROOT_DIR/lib/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_ROOT_DIR in /etc/default/cis-hardening"
    exit 128
fi
