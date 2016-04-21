#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 5.4 Ensure echo is not enabled (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

FILE='/etc/inetd.conf'
PATTERN='^echo'

# This function will be called if the script status is on enabled / audit mode
audit () {
    does_file_exist $FILE
    if [ $FNRET != 0 ]; then
        ok "$FILE does not exist"
    else
        does_pattern_exists_in_file $FILE $PATTERN
        if [ $FNRET = 0 ]; then
            crit "$PATTERN exists, chargen services are enabled!"
        else
            ok "$PATTERN not present in $FILE"
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
        does_pattern_exists_in_file $FILE $PATTERN
        if [ $FNRET = 0 ]; then
            warn "$PATTERN present in $FILE, purging it"
            backup_file $FILE
            ESCAPED_PATTERN=$(sed "s/|\|(\|)/\\\&/g" <<< $PATTERN)
            sed -ie "s/$ESCAPED_PATTERN/#&/g" $FILE
        else
            ok "$PATTERN not present in $FILE"
        fi
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
        exit 128
    fi
fi 

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
[ -r $CIS_ROOT_DIR/lib/main.sh ] && . $CIS_ROOT_DIR/lib/main.sh
