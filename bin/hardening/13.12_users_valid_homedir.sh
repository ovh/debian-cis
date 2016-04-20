#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 13.12 Check That Users Are Assigned Valid Home Directories (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

ERRORS=0

# This function will be called if the script status is on enabled / audit mode
audit () {
    RESULT=$(cat /etc/passwd | awk -F: '{ print $1 ":" $3 ":" $6 }')
    for LINE in $RESULT; do 
        debug "Working on $LINE"
        USER=$(awk -F: {'print $1'} <<< $LINE)
        USERID=$(awk -F: {'print $2'} <<< $LINE)
        DIR=$(awk -F: {'print $3'} <<< $LINE)
        if [ $USERID -ge 1000 -a ! -d "$DIR" -a $USER != "nfsnobody" -a $USER != "nobody" ]; then
            crit "The home directory ($DIR) of user $USER does not exist."
            ERRORS=$((ERRORS+1))    
        fi
    done

    if [ $ERRORS = 0 ]; then
        ok "All home directories exists"
    fi 
}

# This function will be called if the script status is on enabled mode
apply () {
    info "Modifying home directories may seriously harm your system, report only here"
}

# This function will check config parameters required
check_config() {
    :
}

# Source Root Dir Parameter
if [ ! -r /etc/default/cis-hardening ]; then
    echo "There is no /etc/default/cis-hardening FILE, cannot source CIS_ROOT_DIR variable, aborting"
    exit 128
else
    . /etc/default/cis-hardening
    if [ -z $CIS_ROOT_DIR ]; then
        echo "No CIS_ROOT_DIR variable, aborting"
        exit 128
    fi
fi 

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
[ -r $CIS_ROOT_DIR/lib/main.sh ] && . $CIS_ROOT_DIR/lib/main.sh
