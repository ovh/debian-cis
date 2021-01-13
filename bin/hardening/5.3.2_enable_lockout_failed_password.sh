#!/bin/bash

#
# CIS Debian Hardening
#

#
# 5.3.2 Ensure lockout for failed password attempts is configured (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

HARDENING_LEVEL=3
DESCRIPTION="Set lockout for failed password attemps."

PACKAGE='libpam-modules-bin'
PATTERN='^auth[[:space:]]*required[[:space:]]*pam_tally[2]?.so'
FILE='/etc/pam.d/login'

# This function will be called if the script status is on enabled / audit mode
audit () {
    is_pkg_installed $PACKAGE
    if [ $FNRET != 0 ]; then
        crit "$PACKAGE is not installed!"
    else
        ok "$PACKAGE is installed"
        does_pattern_exist_in_file $FILE $PATTERN
        if [ $FNRET = 0 ]; then
            ok "$PATTERN is present in $FILE"
        else
            crit "$PATTERN is not present in $FILE"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    is_pkg_installed $PACKAGE
    if [ $FNRET = 0 ]; then
        ok "$PACKAGE is installed"
    else
        crit "$PACKAGE is absent, installing it"
        apt_install $PACKAGE
    fi
    does_pattern_exist_in_file $FILE $PATTERN
    if [ $FNRET = 0 ]; then
        ok "$PATTERN is present in $FILE"
    else
        crit "$PATTERN is not present in $FILE"
        add_line_file_before_pattern $FILE "auth    required    pam_tally.so onerr=fail deny=6 unlock_time=1800" "# Uncomment and edit \/etc\/security\/time.conf if you need to set"
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
