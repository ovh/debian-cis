#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 5.1.2 Ensure rsh server is not enabled (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

PACKAGE='rsh-server'
FILE='/etc/inetd.conf'
PATTERN='^(shell|login|exec)'

# This function will be called if the script status is on enabled / audit mode
audit () {
    is_pkg_installed $PACKAGE
    if [ $FNRET = 0 ]; then
        warn "$PACKAGE is installed, checking configuration"
        does_file_exist $FILE
        if [ $FNRET != 0 ]; then
            ok "$FILE does not exist"
        else
            does_pattern_exists_in_file $FILE $PATTERN
            if [ $FNRET = 0 ]; then
                crit "$PATTERN exists, $PACKAGE services are enabled !"
            else
                ok "$PATTERN not present in $FILE"
            fi
        fi
    else
        ok "$PACKAGE is absent"
    fi
    :
}

# This function will be called if the script status is on enabled mode
apply () {
    is_pkg_installed $PACKAGE
    if [ $FNRET = 0 ]; then
        crit "$PACKAGE is installed, purging it"
        apt-get purge $PACKAGE -y
    else
        ok "$PACKAGE is absent"
    fi
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
