#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure root login is restricted to system console (Not Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Restrict root login to system console."

FILE='/etc/securetty'

# This function will be called if the script status is on enabled / audit mode
audit() {
    info "Remove terminal entries in $FILE for any consoles that are not in a physically secure location."
    info "No measure here, please review the file by yourself"
}

# This function will be called if the script status is on enabled mode
apply() {
    info "Remove terminal entries in $FILE for any consoles that are not in a physically secure location."
    info "No measure here, please review the file by yourself"
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
