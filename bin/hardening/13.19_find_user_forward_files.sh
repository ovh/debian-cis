#!/bin/bash

#
# CIS Debian 7 Hardening
# Authors : Thibault Dewailly, OVH <thibault.dewailly@corp.ovh.com>
#

#
# 13.19 Check for Presence of User .forward Files (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

ERRORS=0
FILENAME='.forward'

# This function will be called if the script status is on enabled / audit mode
audit () {
    for DIR in $(cat /etc/passwd | egrep -v '(root|halt|sync|shutdown)' | awk -F: '($7 != "/usr/sbin/nologin" && $7 != "/bin/false" && $7 !="/nonexistent" ) { print $6 }'); do
    debug "Working on $DIR"
        for FILE in $DIR/$FILENAME; do
            if [ ! -h "$FILE" -a -f "$FILE" ]; then
                crit "$FILE present"
                ERRORS=$((ERRORS+1))
            fi
        done
    done

    if [ $ERRORS = 0 ]; then
        ok "No $FILENAME present in users files"
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
