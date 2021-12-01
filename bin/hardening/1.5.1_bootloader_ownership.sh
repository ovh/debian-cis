#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 1.5.1 Ensure permissions on bootloader config are configured (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="User and group root owner of grub bootloader config."

# Assertion : Grub Based.

FILE='/boot/grub/grub.cfg'
USER='root'
GROUP='root'
PERMISSIONS='400'
PERMISSIONSOK='400 600'

# This function will be called if the script status is on enabled / audit mode
audit() {
    has_file_correct_ownership "$FILE" "$USER" "$GROUP"
    if [ "$FNRET" = 0 ]; then
        ok "$FILE has correct ownership"
    else
        crit "$FILE ownership was not set to $USER:$GROUP"
    fi

    has_file_one_of_permissions "$FILE" "$PERMISSIONSOK"
    if [ "$FNRET" = 0 ]; then
        ok "$FILE has correct permissions"
    else
        crit "$FILE permissions were not set to $PERMISSIONS"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    has_file_correct_ownership "$FILE" "$USER" "$GROUP"
    if [ "$FNRET" = 0 ]; then
        ok "$FILE has correct ownership"
    else
        info "fixing $FILE ownership to $USER:$GROUP"
        chown "$USER":"$GROUP" "$FILE"
    fi

    has_file_one_of_permissions "$FILE" "$PERMISSIONSOK"
    if [ "$FNRET" = 0 ]; then
        ok "$FILE has correct permissions"
    else
        info "fixing $FILE permissions to $PERMISSIONS"
        chmod 0"$PERMISSIONS" "$FILE"
    fi
}

# This function will check config parameters required
check_config() {

    is_pkg_installed "grub-common"
    if [ "$FNRET" != 0 ]; then
        warn "Grub is not installed, not handling configuration"
        exit 2
    fi
    does_user_exist "$USER"
    if [ "$FNRET" != 0 ]; then
        crit "$USER does not exist"
        exit 2
    fi
    does_group_exist "$GROUP"
    if [ "$FNRET" != 0 ]; then
        crit "$GROUP does not exist"
        exit 2
    fi
    does_file_exist "$FILE"
    if [ "$FNRET" != 0 ]; then
        crit "$FILE does not exist"
        exit 2
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
