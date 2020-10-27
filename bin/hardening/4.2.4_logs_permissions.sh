#!/bin/bash

#
# CIS Debian Hardening
#

#
# 4.2.4 Ensure permissions on all logfiles are configured (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

HARDENING_LEVEL=2
DESCRIPTION="Check permissions on logs (other has no permissions on any files and group does not have write or execute permissions on any file)"

DIR='/var/log'
PERMISSIONS='640'

# This function will be called if the script status is on enabled / audit mode
audit () {
    ERRORS=0
    for FILE in $($SUDO_CMD find $DIR -type f);
    do
        perm=$(stat -L -c '%a' $FILE)
        echo "$perm  ttt $PERMISSIONS"
        if [ "$perm" != "$PERMISSIONS" ]; then
            ERRORS=$((ERRORS+1))
            crit "Some logs in $DIR permissions were not set to $PERMISSIONS"
        fi
    done

    if [ $ERRORS = 0 ]; then
        ok "Logs in $DIR have correct permissions"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    ERRORS=0
    for FILE in $($SUDO_CMD find $DIR -type f);
    do
        perm=$(stat -L -c '%a' $FILE)
        echo "$perm  ttt $PERMISSIONS"
        if [ "$perm" != "$PERMISSIONS" ]; then
            info "fixing $DIR logs permissions to $PERMISSIONS"
            chmod 0$PERMISSIONS $FILE
            
        fi
    done
    
    if [ $ERRORS = 0 ]; then
        ok "Logs in $DIR have correct permissions"
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
