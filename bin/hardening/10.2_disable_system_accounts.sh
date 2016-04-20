#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 10.2 Disable System Accounts (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

SHELL='/bin/false'
FILE='/etc/passwd'
RESULT=''

# This function will be called if the script status is on enabled / audit mode
audit () {
    info "Checking if admin accounts have login different from $SHELL"
    RESULT=$(egrep -v "^\+" $FILE | awk -F: '($1!="root" && $1!="sync" && $1!="shutdown" && $1!="halt" && $3<1000 && $7!="/usr/sbin/nologin" && $7!="/bin/false") {print}') 
    for LINE in $RESULT; do
        debug "line : $LINE"
        ACCOUNT=$( echo $LINE | cut -d: -f 1 )
        debug "Account : $ACCOUNT"
        debug "Exceptions : $EXCEPTIONS"
        debug "echo \"$EXCEPTIONS\" | grep -q $ACCOUNT"
        if echo "$EXCEPTIONS" | grep -q $ACCOUNT; then
            debug "$ACCOUNT is confirmed as an exception"
            RESULT=$(sed "s!$LINE!!" <<< "$RESULT")
        else
            debug "$ACCOUNT not found in exceptions" 
        fi
    done
    if [ ! -z "$RESULT" ]; then
        crit "Some admin accounts have not $SHELL as shell"
        crit "$RESULT"
    else
        ok "All admin accounts deactivated"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    RESULT=$(egrep -v "^\+" $FILE | awk -F: '($1!="root" && $1!="sync" && $1!="shutdown" && $1!="halt" && $3<1000 && $7!="/usr/sbin/nologin" && $7!="/bin/false") {print}')
    for LINE in $RESULT; do
        debug "line : $LINE"
        ACCOUNT=$( echo $LINE | cut -d: -f 1 )
        debug "Account : $ACCOUNT"
        debug "Exceptions : $EXCEPTIONS"
        debug "echo \"$EXCEPTIONS\" | grep -q $ACCOUNT"
        if echo "$EXCEPTIONS" | grep -q $ACCOUNT; then
            debug "$ACCOUNT is confirmed as an exception"
            RESULT=$(sed "s!$LINE!!" <<< "$RESULT")
        else
            debug "$ACCOUNT not found in exceptions"
        fi
    done
    if [ ! -z "$RESULT" ]; then
        warn "Some admin accounts have not $SHELL as shell"
        warn "$RESULT"
        for USER in $( echo "$RESULT" | cut -d: -f 1 ); do
            info "Setting $SHELL to $USER"
            usermod -s $SHELL $USER            
        done
    else
        ok "All admin accounts deactivated, nothing to apply"
    fi
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
    if [ -z $CIS_ROOT_DIR ]; then
        echo "No CIS_ROOT_DIR variable, aborting"
        exit 128
    fi
fi 

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
[ -r $CIS_ROOT_DIR/lib/main.sh ] && . $CIS_ROOT_DIR/lib/main.sh
