#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 1.5.2 Ensure bootloader password is set (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Setting bootloader password to secure boot parameters."

FILE='/boot/grub/grub.cfg'
USER_PATTERN="^set superusers"
PWD_PATTERN="^password_pbkdf2"

# This function will be called if the script status is on enabled / audit mode
audit() {
    does_pattern_exist_in_file "$FILE" "$USER_PATTERN"
    if [ "$FNRET" != 0 ]; then
        crit "$USER_PATTERN not present in $FILE"
    else
        ok "$USER_PATTERN is present in $FILE"
    fi
    does_pattern_exist_in_file "$FILE" "$PWD_PATTERN"
    if [ "$FNRET" != 0 ]; then
        crit "$PWD_PATTERN not present in $FILE"
    else
        ok "$PWD_PATTERN is present in $FILE"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    does_pattern_exist_in_file "$FILE" "$USER_PATTERN"
    if [ "$FNRET" != 0 ]; then
        warn "$USER_PATTERN not present in $FILE, please configure password for grub"
    else
        ok "$USER_PATTERN is present in $FILE"
    fi
    does_pattern_exist_in_file "$FILE" "$PWD_PATTERN"
    if [ "$FNRET" != 0 ]; then
        warn "$PWD_PATTERN not present in $FILE, please configure password for grub"
    else
        ok "$PWD_PATTERN is present in $FILE"
    fi
}

# This function will check config parameters required
check_config() {
    is_pkg_installed "grub-common"
    if [ "$FNRET" != 0 ]; then
        warn "Grub is not installed, not handling configuration"
        exit 2
    fi
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
