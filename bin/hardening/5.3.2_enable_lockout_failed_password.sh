#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 5.3.2 Ensure lockout for failed password attempts is configured (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Set lockout for failed password attemps."

PACKAGE='libpam-modules-bin'
PATTERN_AUTH='^auth[[:space:]]*required[[:space:]]*pam_((tally[2]?)|(faillock))\.so'
PATTERN_ACCOUNT='pam_((tally[2]?)|(faillock))\.so'
FILE_AUTH='/etc/pam.d/common-auth'
FILE_ACCOUNT='/etc/pam.d/common-account'

# This function will be called if the script status is on enabled / audit mode
audit() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        crit "$PACKAGE is not installed!"
    else
        ok "$PACKAGE is installed"
        does_pattern_exist_in_file "$FILE_AUTH" "$PATTERN_AUTH"
        if [ "$FNRET" = 0 ]; then
            ok "$PATTERN_AUTH is present in $FILE_AUTH"
        else
            crit "$PATTERN_AUTH is not present in $FILE_AUTH"
        fi
        does_pattern_exist_in_file "$FILE_ACCOUNT" "$PATTERN_ACCOUNT"
        if [ "$FNRET" = 0 ]; then
            ok "$PATTERN_ACCOUNT is present in $FILE_ACCOUNT"
        else
            crit "$PATTERN_ACCOUNT is not present in $FILE_ACCOUNT"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" = 0 ]; then
        ok "$PACKAGE is installed"
    else
        crit "$PACKAGE is absent, installing it"
        apt_install "$PACKAGE"
    fi
    does_pattern_exist_in_file "$FILE_AUTH" "$PATTERN_AUTH"
    if [ "$FNRET" = 0 ]; then
        ok "$PATTERN_AUTH is present in $FILE_AUTH"
    else
        warn "$PATTERN_AUTH is not present in $FILE_AUTH, adding it"
        if [ 10 -ge "$DEB_MAJ_VER" ]; then
            add_line_file_before_pattern "$FILE_AUTH" "auth required pam_tally2.so onerr=fail audit silent deny=5 unlock_time=900" "# pam-auth-update(8) for details."
        else
            add_line_file_before_pattern "$FILE_AUTH" "auth required pam_faillock.so onerr=fail audit silent deny=5 unlock_time=900" "# pam-auth-update(8) for details."
        fi
    fi
    does_pattern_exist_in_file "$FILE_ACCOUNT" "$PATTERN_ACCOUNT"
    if [ "$FNRET" = 0 ]; then
        ok "$PATTERN_ACCOUNT is present in $FILE_ACCOUNT"
    else
        warn "$PATTERN_ACCOUNT is not present in $FILE_ACCOUNT, adding it"
        if [ 10 -ge "$DEB_MAJ_VER" ]; then
            add_line_file_before_pattern "$FILE_ACCOUNT" "account required pam_tally2.so" "# pam-auth-update(8) for details."
        else
            add_line_file_before_pattern "$FILE_ACCOUNT" "account required pam_faillock.so" "# pam-auth-update(8) for details."
        fi

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
