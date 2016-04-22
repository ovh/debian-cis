#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 3.1 Set User/Group Owner on bootloader config (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# Assertion : Grub Based.

FILE='/boot/grub/grub.cfg'
USER='root'
GROUP='root'

# This function will be called if the script status is on enabled / audit mode
audit () {
    has_file_correct_ownership $FILE $USER $GROUP
    if [ $FNRET = 0 ]; then
        ok "$FILE has correct ownership"
    else
        crit "$FILE is not $USER:$GROUP ownership set"
    fi 
}

# This function will be called if the script status is on enabled mode
apply () {
    has_file_correct_ownership $FILE $USER $GROUP
    if [ $FNRET = 0 ]; then
        ok "$FILE has correct ownership"
    else
        info "fixing $FILE ownership to $USER:$GROUP"
        chown $USER:$GROUP $FILE
    fi
}

# This function will check config parameters required
check_config() {

    is_pkg_installed "grub-pc"
    if [ $FNRET != 0 ]; then
        warn "Grub is not installed, not handling configuration"
        exit 128
    fi
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
    does_file_exist $FILE
    if [ $FNRET != 0 ]; then
        crit "$FILE does not exist"
        exit 128
    fi
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
