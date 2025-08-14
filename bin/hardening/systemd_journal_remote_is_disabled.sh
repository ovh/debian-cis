#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure systemd-journal-remote service is not in use (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure systemd-journal-remote service is not in use : client is able to send logs, not receive them"
SERVICE="systemd-journal-remote.service"
SOCKET="systemd-journal-remote.socket"

# This function will be called if the script status is on enabled / audit mode
audit() {
    SERVICE_ENABLED=1
    SERVICE_ACTIVE=1
    SOCKET_ENABLED=1
    SOCKET_ACTIVE=1

    is_service_enabled "$SERVICE"
    if [ "$FNRET" -eq 0 ]; then
        crit "$SERVICE is enabled"
        SERVICE_ENABLED=0
    else
        ok "$SERVICE is not enabled"
    fi

    is_service_active "$SERVICE"
    if [ "$FNRET" -eq 0 ]; then
        crit "$SERVICE is active"
        SERVICE_ACTIVE=0
    else
        ok "$SERVICE is not active"
    fi

    is_socket_enabled "$SOCKET"
    if [ "$FNRET" -eq 0 ]; then
        crit "$SOCKET is enabled"
        SOCKET_ENABLED=0
    else
        ok "$SOCKET is not enabled"
    fi

    is_socket_active "$SOCKET"
    if [ "$FNRET" -eq 0 ]; then
        crit "$SOCKET is active"
        SOCKET_ACTIVE=0
    else
        ok "$SOCKET is not active"
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$SERVICE_ENABLED" -eq 0 ]; then
        info "Disabling and masking $SERVICE"
        manage_service disable "$SERVICE"
        manage_service mask "$SERVICE"
    fi

    if [ "$SERVICE_ACTIVE" -eq 0 ]; then
        info "Stopping $SERVICE"
        manage_service stop "$SERVICE"
    fi

    if [ "$SOCKET_ENABLED" -eq 0 ]; then
        info "Disabling and masking $SOCKET"
        manage_service disable "$SOCKET"
        manage_service mask "$SOCKET"
    fi

    if [ "$SOCKET_ACTIVE" -eq 0 ]; then
        info "Stopping $SOCKET"
        manage_service stop "$SOCKET"
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
