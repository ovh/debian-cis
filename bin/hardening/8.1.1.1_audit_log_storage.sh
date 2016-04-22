#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 8.1.1.1 Configure Audit Log Storage Size (Not Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

FILE='/etc/audit/auditd.conf'
PATTERN='max_log_file'
VALUE=5

# This function will be called if the script status is on enabled / audit mode
audit () {
    does_file_exist $FILE
    if [ $FNRET != 0 ]; then
        crit "$FILE does not exist"
    else
        ok "$FILE exist, checking configuration"
        does_pattern_exists_in_file $FILE "^$PATTERN[[:space:]]"
        if [ $FNRET != 0 ]; then
            crit "$PATTERN not present in $FILE"
        else
            ok "$PATTERN present in $FILE"
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
        ok "$FILE exist"
    fi
    does_pattern_exists_in_file $FILE "^$PATTERN[[:space:]]"
    if [ $FNRET != 0 ]; then
        warn "$PATTERN not present in $FILE, adding it"
        add_end_of_file $FILE "$PATTERN = $VALUE"
    else
        ok "$PATTERN present in $FILE"
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
