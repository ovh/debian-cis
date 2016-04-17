#!/bin/bash

#
# CIS Debian 7 Hardening
# Authors : Thibault Dewailly, OVH <thibault.dewailly@corp.ovh.com>
#

#
# 13.11 Check Groups in /etc/passwd (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

ERRORS=0

# This function will be called if the script status is on enabled / audit mode
audit () {

    for GROUP in $(cut -s -d: -f4 /etc/passwd | sort -u ); do
        debug "Working on group $GROUP"
        if ! grep -q -P "^.*?:[^:]*:$GROUP:" /etc/group; then
            crit "Group $GROUP is referenced by /etc/passwd but does not exist in /etc/group"
            ERRORS=$(($ERRORS+1))
        fi
    done

    if [ $ERRORS = 0 ]; then
        ok "passwd and group Groups are consistent"
    fi 
}

# This function will be called if the script status is on enabled mode
apply () {
    for GROUP in $(cut -s -d: -f4 /etc/passwd | sort -u ); do
        debug "Working on group $GROUP"
        if ! grep -q -P "^.*?:[^:]*:$GROUP:" /etc/group; then
            crit "Group $GROUP is referenced by /etc/passwd but does not exist in /etc/group"
            ERRORS=$(($ERRORS+1))
        fi
    done

    if [ $ERRORS != 0 ]; then
        warn "Consider creating missing group"
    fi
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
