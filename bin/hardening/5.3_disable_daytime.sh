#!/bin/bash

#
# CIS Debian 7/8 Hardening
#

#
# 5.3 Ensure daytime is not enabled (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

HARDENING_LEVEL=2

FILE='/etc/inetd.conf'
PATTERN='^daytime'

# This function will be called if the script status is on enabled / audit mode
audit () {
    does_file_exist $FILE
    if [ $FNRET != 0 ]; then
        ok "$FILE does not exist"
    else
        does_pattern_exist_in_file $FILE $PATTERN
        if [ $FNRET = 0 ]; then
            crit "$PATTERN exists, daytime service is enabled!"
        else
            ok "$PATTERN is not present in $FILE"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    does_file_exist $FILE
    if [ $FNRET != 0 ]; then
        ok "$FILE does not exist"
    else
        info "$FILE exists, checking patterns"
        does_pattern_exist_in_file $FILE $PATTERN
        if [ $FNRET = 0 ]; then
            warn "$PATTERN is present in $FILE, purging it"
            backup_file $FILE
            ESCAPED_PATTERN=$(sed "s/|\|(\|)/\\\&/g" <<< $PATTERN)
            sed -ie "s/$ESCAPED_PATTERN/#&/g" $FILE
        else
            ok "$PATTERN is not present in $FILE"
        fi
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
