#!/bin/bash

#
# CIS Debian 7/8 Hardening
#

#
# 10.5 Lock Inactive User Accounts (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

HARDENING_LEVEL=3
DESCRIPTION="Lock inactive user accounts."

# This function will be called if the script status is on enabled / audit mode
audit () {
    info "Looking at the manual of useradd, it seems that this recommendation does not fill the title"
    info "The number of days after a password expires until the account is permanently disabled."
    info "Which is not inactive users per se"
}

# This function will be called if the script status is on enabled mode
apply () {
    info "Looking at the manual of useradd, it seems that this recommendation does not fill the title"
    info "The number of days after a password expires until the account is permanently disabled."
    info "Which is not inactive users per se"
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
