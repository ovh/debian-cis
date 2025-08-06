#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure chrony is enabled and running (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure chrony is enabled and running."
PACKAGE="chrony"
SERVICE="chrony"

# This function will be called if the script status is on enabled / audit mode
audit() {
    CHRONY_INSTALLED=0
    CHRONY_ENABLED=0
    CHRONY_RUNNING=0

    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" -ne 0 ]; then
        CHRONY_INSTALLED=1
        crit "$PACKAGE is not installed"
    fi
    # no package, no need to check further
    return

    is_service_enabled "$SERVICE"
    if [ "$FNRET" -ne 0 ]; then
        CHRONY_ENABLED=1
        crit "$SERVICE is not enabled"
    fi

    is_service_active "$SERVICE"
    if [ "$FNRET" -ne 0 ]; then
        CHRONY_RUNNING=1
        crit "$SERVICE is not running"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$CHRONY_INSTALLED" -eq 1 ]; then
        # this may be chrony, as it may be ntp or systemd-timesyncd
        warn "Please install $PACKAGE manually to ensure only one time synchronization system is installed"
    fi

    if [ "$CHRONY_ENABLED" -eq 1 ]; then
        info "Enabling $SERVICE service"
        manage_service "enable" "$SERVICE"
    fi

    if [ "$CHRONY_RUNNING" -eq 1 ]; then
        info "Starting $SERVICE service"
        manage_service "start" "$SERVICE"
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
