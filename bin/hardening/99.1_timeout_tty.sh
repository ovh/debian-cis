#!/bin/bash

#
# CIS Debian 7 Hardening /!\ Not in the Guide
#

#
# 99.1 Set Timeout on ttys
#

set -e # One error, it's over
set -u # One variable unset, it's over

USER='root'
PATTERN='^TMOUT='
VALUE='600'
FILES_TO_SEARCH='/etc/bash.bashrc /etc/profile.d/* /etc/profile'
FILE='/etc/profile.d/CIS_99.1_timeout.sh'

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
        chmod 644 $FILE
        add_end_of_file $FILE "$PATTERN$VALUE"
        add_end_of_file $FILE "readonly TMOUT"
        add_end_of_file $FILE "export TMOUT"
    else
        ok "$PATTERN present in $FILES_TO_SEARCH"
    fi
}

# This function will check config parameters required
check_config() {
    :
}

# Source Root Dir Parameter
if [ ! -r /etc/default/cis-hardening ]; then
    echo "There is no /etc/default/cis-hardening file, cannot source CIS_ROOT_DIR variable, aborting"
    exit 128
else
    . /etc/default/cis-hardening
    if [ -z $CIS_ROOT_DIR ]; then
        echo "No CIS_ROOT_DIR variable, aborting"
    fi
fi 

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
[ -r $CIS_ROOT_DIR/lib/main.sh ] && . $CIS_ROOT_DIR/lib/main.sh
