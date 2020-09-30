#!/bin/bash

#
# CIS Debian Hardening
#

#
# 1.3.1 Ensure AIDE is installed (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

HARDENING_LEVEL=3
DESCRIPTION="Install AIDE which takes a snapshot of filesystem state (can help toi detect modification on the system)."

PACKAGE='aide'

# This function will be called if the script status is on enabled / audit mode
audit () {
    is_pkg_installed $PACKAGE
    if [ $FNRET != 0 ]; then
        crit "$PACKAGE is not installed!"
    else
        ok "$PACKAGE is installed"
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
        aideinit
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