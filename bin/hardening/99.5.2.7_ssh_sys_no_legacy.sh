#!/bin/bash

# run-shellcheck
#
# Legacy CIS Debian Hardening
#

#
# 99.5.2.7 Ensure that legacy services rlogin, rlogind and rcp are disabled and not installed
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure that legacy services rlogin, rlogind and rcp are disabled and not installed"

# shellcheck disable=2034
SERVICES="rlogin rlogind rcp"

# This function will be called if the script status is on enabled / audit mode
audit() {
    for SERVICE in $SERVICES; do
        info "Checking if $SERVICE is enabled and installed"
        is_service_enabled "$SERVICE"
        if [ "$FNRET" != 0 ]; then
            ok "$SERVICE is disabled"
        else
            crit "$SERVICE is enabled"
        fi
        is_pkg_installed "$SERVICE"
        if [ "$FNRET" != 0 ]; then
            ok "$SERVICE is not installed"
        else
            warn "$SERVICE is installed"
        fi
    done
}

# This function will be called if the script status is on enabled mode
apply() {
    :
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
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment, cannot source CIS_ROOT_DIR variable, aborting"
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
