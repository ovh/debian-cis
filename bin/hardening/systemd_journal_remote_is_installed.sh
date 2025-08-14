#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure systemd-journal-remote is installed (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure systemd-journal-remote is installed"
PACKAGE="systemd-journal-remote"

# This function will be called if the script status is on enabled / audit mode
audit() {
    PACKAGE_INSTALLED=1
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        crit "$PACKAGE is absent!"
    else
        PACKAGE_INSTALLED=0
        ok "$PACKAGE is installed"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$PACKAGE_INSTALLED" -eq 1 ]; then
        info "installing '$PACKAGE'"
        apt_install "$PACKAGE"
        info "'$PACKAGE' installed"
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
