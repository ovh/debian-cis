#!/bin/bash

#
# CIS Debian 7 Hardening
# Authors : Thibault Dewailly, OVH <thibault.dewailly@corp.ovh.com>
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
    eval $(RESULT=$(egrep -v "^\+" $FILE | awk -F: '($1!="root" && $1!="sync" && $1!="shutdown" && $1!="halt" && $3<1000 && $7!="/usr/sbin/nologin" && $7!="/bin/false") {print}' | grep -v "$EXCEPTIONS"))
    if [ ! -z "$RESULT" ]; then
        crit "Some admin accounts have not $SHELL as shell"
        crit "$RESULT"
    else
        ok "All admin accounts deactivated"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    eval $(RESULT=$(egrep -v "^\+" $FILE | awk -F: '($1!="root" && $1!="sync" && $1!="shutdown" && $1!="halt" && $3<1000 && $7!="/usr/sbin/nologin" && $7!="/bin/false") {print}' | grep -v "$EXCEPTIONS"))
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
    if [ -z $EXCEPTIONS ]; then
        EXCEPTIONS="@"
    fi
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
