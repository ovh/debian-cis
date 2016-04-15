#!/bin/bash

#
# CIS Debian 7 Hardening
# Authors : Thibault Dewailly, OVH <thibault.dewailly@corp.ovh.com>
#

#
# 10.4 Set Default umask for Users (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

USER='root'
PATTERN='umask 077'
FILES_TO_SEARCH='/etc/bash.bashrc /etc/profile.d/*'
FILE='/etc/profile.d/CIS_10.4_umask.sh'

# This function will be called if the script status is on enabled / audit mode
audit () {
    does_pattern_exists_in_file "$FILES_TO_SEARCH" "^$PATTERN"
    if [ $FNRET != 0 ]; then
        crit "$PATTERN not present in $FILES_TO_SEARCH"
    else
        ok "$PATTERN present in $FILES_TO_SEARCH"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    does_pattern_exists_in_file "$FILES_TO_SEARCH" "^$PATTERN"
    if [ $FNRET != 0 ]; then
        warn "$PATTERN not present in $FILES_TO_SEARCH"
        touch $FILE
        chmod 700 $FILE
        add_end_of_file $FILE "$PATTERN"
    else
        ok "$PATTERN present in $FILES_TO_SEARCH"
    fi
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
