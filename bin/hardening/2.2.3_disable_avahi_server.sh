#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 2.2.3 Ensure Avahi Server is not enabled (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure Avahi server is not enabled."

PACKAGES='avahi-daemon libavahi-common-data libavahi-common3 libavahi-core7'

# This function will be called if the script status is on enabled / audit mode
audit() {
    for PACKAGE in $PACKAGES; do
        is_pkg_installed "$PACKAGE"
        if [ "$FNRET" = 0 ]; then
            crit "$PACKAGE is installed!"
        else
            ok "$PACKAGE is absent"
        fi
    done
}

# This function will be called if the script status is on enabled mode
apply() {
    for PACKAGE in $PACKAGES; do
        is_pkg_installed "$PACKAGE"
        if [ "$FNRET" = 0 ]; then
            crit "$PACKAGE is installed, purging it"
            apt-get purge "$PACKAGE" -y
            apt-get autoremove -y
        else
            ok "$PACKAGE is absent"
        fi
    done
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
