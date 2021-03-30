#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 5.2.1 Ensure permissions on /etc/ssh/sshd_config are configured (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Checking permissions and ownership to root 600 for sshd_config."

PACKAGE='openssh-server'
FILE='/etc/ssh/sshd_config'
PERMISSIONS='600'
USER='root'
GROUP='root'

# This function will be called if the script status is on enabled / audit mode
audit() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        ok "$PACKAGE is not installed!"
    else
        has_file_correct_ownership "$FILE" "$USER" "$GROUP"
        if [ "$FNRET" = 0 ]; then
            ok "$FILE has correct ownership"
        else
            crit "$FILE ownership was not set to $USER:$GROUP"
        fi
        has_file_correct_permissions "$FILE" "$PERMISSIONS"
        if [ "$FNRET" = 0 ]; then
            ok "$FILE has correct permissions"
        else
            crit "$FILE permissions were not set to $PERMISSIONS"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        ok "$PACKAGE is not installed"
    else
        does_file_exist "$FILE"
        if [ "$FNRET" != 0 ]; then
            info "$FILE does not exist"
            touch "$FILE"
        fi
        has_file_correct_ownership "$FILE" "$USER" "$GROUP"
        if [ "$FNRET" = 0 ]; then
            ok "$FILE has correct ownership"
        else
            warn "fixing $FILE ownership to $USER:$GROUP"
            chown "$USER":"$GROUP" "$FILE"
        fi
        has_file_correct_permissions "$FILE" "$PERMISSIONS"
        if [ "$FNRET" = 0 ]; then
            ok "$FILE has correct permissions"
        else
            info "fixing $FILE permissions to $PERMISSIONS"
            chmod 0"$PERMISSIONS" "$FILE"
        fi
    fi
}

# This function will check config parameters required
check_config() {
    does_user_exist "$USER"
    if [ "$FNRET" != 0 ]; then
        crit "$USER does not exist"
        exit 128
    fi
    does_group_exist "$GROUP"
    if [ "$FNRET" != 0 ]; then
        crit "$GROUP does not exist"
        exit 128
    fi
}

# Source Root Dir Parameter
if [ -r /etc/default/cis-hardening ]; then
    # shellcheck source=../../debian/default
    . /etc/default/cis-hardening
fi
if [ -z "$CIS_ROOT_DIR" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_ROOT_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r "$CIS_ROOT_DIR"/lib/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "$CIS_ROOT_DIR"/lib/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_ROOT_DIR in /etc/default/cis-hardening"
    exit 128
fi
