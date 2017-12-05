#!/bin/bash

#
# CIS Debian 7/8 Hardening
#

#
# 7.4.4 Create /etc/hosts.deny (Not Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

HARDENING_LEVEL=3

FILE='/etc/hosts.deny'
PATTERN='ALL: ALL'

# This function will be called if the script status is on enabled / audit mode
audit () {
    does_file_exist $FILE
    if [ $FNRET != 0 ]; then
        crit "$FILE does not exist"
    else
        ok "$FILE exists, checking configuration"
        does_pattern_exist_in_file $FILE "$PATTERN"
        if [ $FNRET != 0 ]; then
            crit "$PATTERN is not present in $FILE, we have to deny everything"
        else
            ok "$PATTERN is present in $FILE"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    does_file_exist $FILE
    if [ $FNRET != 0 ]; then
        warn "$FILE does not exist, creating it"
        touch $FILE
    else
        ok "$FILE exists"
    fi
    does_pattern_exist_in_file $FILE "$PATTERN"
    if [ $FNRET != 0 ]; then
        crit "$PATTERN is not present in $FILE, we have to deny everything"
        add_end_of_file $FILE "$PATTERN"
        warn "YOU MAY HAVE CUT YOUR ACCESS, CHECK BEFORE DISCONNECTING"
    else
        ok "$PATTERN is present in $FILE"
    fi
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
