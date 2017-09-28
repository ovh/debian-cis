#!/bin/bash

#
# CIS Debian 7/8 Hardening
#

#
# 13.11 Check Groups in /etc/passwd (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

HARDENING_LEVEL=2

ERRORS=0

# This function will be called if the script status is on enabled / audit mode
audit () {

    for GROUP in $(cut -s -d: -f4 /etc/passwd | sort -u ); do
        debug "Working on group $GROUP"
        if ! grep -q -P "^.*?:[^:]*:$GROUP:" /etc/group; then
            crit "Group $GROUP is referenced by /etc/passwd but does not exist in /etc/group"
            ERRORS=$((ERRORS+1))
        fi
    done

    if [ $ERRORS = 0 ]; then
        ok "passwd and group Groups are consistent"
    fi 
}

# This function will be called if the script status is on enabled mode
apply () {
    info "Solving passwd and group consistency automatically may seriously harm your system, report only here"
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
