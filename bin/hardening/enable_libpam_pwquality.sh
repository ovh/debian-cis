#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure pam_pwquality module is enabled (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure pam_pwquality module is enabled."

PATTERN_COMMON='pam_pwquality.so'
FILE_COMMON='/etc/pam.d/common-password'

# This function will be called if the script status is on enabled / audit mode
audit() {
    does_pattern_exist_in_file "$FILE_COMMON" "$PATTERN_COMMON"
    if [ "$FNRET" = 0 ]; then
        ok "$PATTERN_COMMON is present in $FILE_COMMON"
    else
        crit "$PATTERN_COMMON is not present in $FILE_COMMON"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    does_pattern_exist_in_file $FILE_COMMON $PATTERN_COMMON
    if [ "$FNRET" = 0 ]; then
        ok "$PATTERN_COMMON is present in $FILE_COMMON"
    else
        warn "$PATTERN_COMMON is not present in $FILE_COMMON"
        add_line_file_before_pattern "$FILE_COMMON" "password requisite pam_pwquality.so retry=3" "# pam-auth-update(8) for details."
    fi
}

# This function will check config parameters required
check_config() {
    :
}

# Source Root Dir Parameter
if [ -r /etc/default/cis-hardening ]; then
    # shellcheck source=../../debian/default
    . /etc/default/cis-hardening
fi
if [ -z "$CIS_LIB_DIR" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_LIB_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r "${CIS_LIB_DIR}"/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "${CIS_LIB_DIR}"/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_LIB_DIR in /etc/default/cis-hardening"
    exit 128
fi
