#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure a single time synchronization daemon is in use (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure a single time synchronization is in use"

PACKAGES="systemd-timesyncd ntp ntpsec chrony"

# This function will be called if the script status is on enabled / audit mode
audit() {
    local count=0
    for PACKAGE in $PACKAGES; do
        is_pkg_installed "$PACKAGE"
        if [ "$FNRET" -eq 0 ]; then
            count=$(("$count" + 1))
        fi
    done
    if [ "$count" -eq 0 ]; then
        crit "None of the following time sync packages are installed: $PACKAGES"
    elif [ "$count" -gt 1 ]; then
        crit "Multiple time sync packages are installed, from $PACKAGES. Pick one and remove the others"
    else
        info "A single time sync package from $PACKAGES is installed"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    info "This recommendation has to be reviewed and applied manually"
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
