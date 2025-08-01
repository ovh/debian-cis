#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure system is disabled when audit logs are full (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=4
# shellcheck disable=2034
DESCRIPTION="Ensure system is disabled when audit logs are full"
AUDIT_CONF="/etc/audit/auditd.conf"

# This function will be called if the script status is on enabled / audit mode
# shellcheck disable=2120
audit() {
    local disk_full_action=""
    local disk_error_action=""

    DISK_FULL_ACTION_IS_VALID=0
    DISK_ERROR_ACTION_IS_VALID=0

    # shellcheck disable=2016
    # otherwise $2 will interpreted in awk, this is not what is intended
    disk_full_action=$($SUDO_CMD grep -E "^[[:space:]]?disk_full_action" "$AUDIT_CONF" | awk -F '=' '{print $2}' | sed 's/\ //g')
    # shellcheck disable=2016
    disk_error_action=$($SUDO_CMD grep -E "^[[:space:]]?disk_error_action" "$AUDIT_CONF" | awk -F '=' '{print $2}' | sed 's/\ //g')

    if [ "$disk_full_action" != "halt" ] && [ "$disk_full_action" != 'single' ]; then
        DISK_FULL_ACTION_IS_VALID=1
        crit "'disk_full_action' is not configured to 'halt' or 'single'"
        warn "The recommendation is to stop the system when the logs disk is full. Make sure to understand the consequences before applying it"
    else
        ok "'disk_full_action' is configured to 'halt' or 'single'"
    fi

    if [ "$disk_error_action" != "halt" ] && [ "$disk_error_action" != 'single' ] && [ "$disk_error_action" != 'syslog' ]; then
        DISK_ERROR_ACTION_IS_VALID=1
        crit "'disk_error_action' is not configured to 'syslog', 'halt' or 'single'"
        warn "The recommendation is to stop the system when there are errors on the logs disk. Make sure to understand the consequences before applying it"
    else
        ok "'disk_error_action' is configured to 'syslog', 'halt' or 'single'"
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$DISK_FULL_ACTION_IS_VALID" -eq 1 ]; then
        replace_in_file "$AUDIT_CONF" "^[[:space:]]\?disk_full_action" "disk_full_action = halt"
    fi

    if [ "$DISK_ERROR_ACTION_IS_VALID" -eq 1 ]; then
        replace_in_file "$AUDIT_CONF" "^[[:space:]]\?disk_error_action" "disk_error_action = halt"
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
