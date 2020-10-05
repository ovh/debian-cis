#!/bin/bash

#
# CIS Debian Hardening
#

#
# 5.2.2 Ensure permissions on SSH private host key files are configured (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

HARDENING_LEVEL=1
DESCRIPTION="Checking permissions and ownership to root 600 for ssh private keys. "

DIR='/etc/ssh'
PERMISSIONS='600'
USER='root'
GROUP='root'
OPTIONS=(-xdev -type f -name "ssh_host_*_key")

# This function will be called if the script status is on enabled / audit mode
audit () {
    have_files_in_dir_correct_ownership $DIR $USER $GROUP OPTIONS
    if [ $FNRET = 0 ]; then
        ok "SSH public keys in $DIR have correct ownership"
    else
        crit "Some $DIR SSH public keys ownership were not set to $USER:$GROUP"
    fi
    have_files_in_dir_correct_permissions $DIR $PERMISSIONS OPTIONS
    if [ $FNRET = 0 ]; then
        ok "SSH public keys in $DIR have correct permissions"
    else
        crit "Some $DIR SSH public keys permissions were not set to $PERMISSIONS"
    fi 
}

# This function will be called if the script status is on enabled mode
apply () {

    have_files_in_dir_correct_ownership $DIR $USER $GROUP OPTIONS
    if [ $FNRET = 0 ]; then
        ok "SSH public keys in $DIR have correct ownership"
    else
        warn "fixing $DIR SSH public keys ownership to $USER:$GROUP"
        find /etc/ssh -xdev -type f -name 'ssh_host_*_key.pub' -exec chown root:root {} \;
    fi
    have_files_in_dir_correct_permissions $DIR $PERMISSIONS OPTIONS
    if [ $FNRET = 0 ]; then
        ok "SSH public keys in $DIR have correct permissions"
    else
        info "fixing $DIR SSH public keys permissions to $PERMISSIONS"
        find /etc/ssh -xdev -type f -name 'ssh_host_*_key.pub' -exec chmod 0600 {} \;
    fi
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
