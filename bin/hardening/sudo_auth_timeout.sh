#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure sudo authentication timeout is configured correctly (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure sudo authentication timeout is configured correctly"
TIMEOUT_VALUE=15

# This function will be called if the script status is on enabled / audit mode
# shellcheck disable=2120
audit() {
    SUDO_TIMEOUT_IS_VALID=0

    local timestamp_timeout
    local sudo_files

    sudo_files="/etc/sudoers $(find /etc/sudoers.d -type f ! -name README | paste -s)"
    # shellcheck disable=2016
    # shellcheck disable=2086
    timestamp_timeout=$($SUDO_CMD grep "timestamp_timeout" $sudo_files | awk -F '=' '{print $2}')

    if [ "$(wc -l <<<"$timestamp_timeout")" -eq 0 ]; then
        # look for the default
        # shellcheck disable=2016
        timestamp_timeout=$(sudo -V | awk -F ':' '/Authentication timestamp timeout/ {print $2}' | sed -e 's/\..*$//' -e 's/\ //g')
        if [ "$timestamp_timeout" -le "$TIMEOUT_VALUE" ]; then
            ok "sudo timestamp timeout is $timestamp_timeout"
        else
            crit "sudo timestamp timeout is $timestamp_timeout"
            SUDO_TIMEOUT_IS_VALID=1
        fi
    else
        for timeout in $timestamp_timeout; do
            if [ "$timeout" -le "$TIMEOUT_VALUE" ]; then
                ok "sudo timestamp timeout is $timeout"
            else
                crit "sudo timestamp timeout is $timeout"
                SUDO_TIMEOUT_IS_VALID=1
            fi
        done
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    audit
    if [ "$SUDO_TIMEOUT_IS_VALID" -ne 0 ]; then

        sudo_files="/etc/sudoers $(find /etc/sudoers.d -type f ! -name README | paste -s)"
        for file in $sudo_files; do
            delete_line_in_file "$file" "timestamp_timeout"
        done
        add_end_of_file /etc/sudoers "Defaults timestamp_timeout=$TIMEOUT_VALUE"

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
