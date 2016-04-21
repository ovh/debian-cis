#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 9.1.8 Restrict at/cron to Authorized Users (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

FILES_ABSENT='/etc/cron.deny /etc/at.deny'
FILES_PRESENT='/etc/cron.allow /etc/at.allow'
PERMISSIONS='600'
USER='root'
GROUP='root'

# This function will be called if the script status is on enabled / audit mode
audit () {
    for FILE in $FILES_ABSENT; do
        does_file_exist $FILE
        if [ $FNRET = 0 ]; then
            crit "$FILE exists"
        else
            ok "$FILE is absent"
        fi
    done
    for FILE in $FILES_PRESENT; do
        does_file_exist $FILE
        if [ $FNRET != 0 ]; then
            crit "$FILE is absent"
        else
            has_file_correct_ownership $FILE $USER $GROUP
            if [ $FNRET = 0 ]; then
                ok "$FILE has correct ownership"
            else
                crit "$FILE is not $USER:$GROUP ownership set"
            fi
            has_file_correct_permissions $FILE $PERMISSIONS
            if [ $FNRET = 0 ]; then
                ok "$FILE has correct permissions"
            else
                crit "$FILE permissions were not set to $PERMISSIONS"
            fi 
        fi
    done
}

# This function will be called if the script status is on enabled mode
apply () {
    for FILE in $FILES_ABSENT; do
        does_file_exist $FILE
        if [ $FNRET = 0 ]; then
            warn "$FILE exists"
            rm $FILE
        else
            ok "$FILE is absent"
        fi
    done
    for FILE in $FILES_PRESENT; do
        does_file_exist $FILE
        if [ $FNRET != 0 ]; then
            warn "$FILE is absent"
            touch $FILE
        fi
        has_file_correct_ownership $FILE $USER $GROUP
        if [ $FNRET = 0 ]; then
            ok "$FILE has correct ownership"
        else
            warn "$FILE is not $USER:$GROUP ownership set"
            chown $USER:$GROUP $FILE
        fi
        has_file_correct_permissions $FILE $PERMISSIONS
        if [ $FNRET = 0 ]; then
            ok "$FILE has correct permissions"
        else
            warn "$FILE permissions were not set to $PERMISSIONS"
            chmod 0$PERMISSIONS $FILE
        fi
    done
}

# This function will check config parameters required
check_config() {
    does_user_exist $USER
    if [ $FNRET != 0 ]; then
        crit "$USER does not exist"
        exit 128
    fi
    does_group_exist $GROUP
    if [ $FNRET != 0 ]; then
        crit "$GROUP does not exist"
        exit 128
    fi
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
