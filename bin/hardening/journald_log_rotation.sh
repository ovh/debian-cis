#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure journald log file rotation is configured (Manual)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure journald log file rotation is configured (Manual)"

# we wont check the values, that are specific to each user, only that the parameters are present
PARAMS_TO_CHECK="SystemMaxUse SystemKeepFree RuntimeMaxUse RuntimeKeepFree MaxFileSec"

# This function will be called if the script status is on enabled / audit mode
audit() {
    JOURNALD_LOG_ROTATION_VALID=0
    files_to_check="/etc/systemd/journald.conf"
    if [ -d /etc/systemd/journald.conf.d ]; then
        files_to_check="$files_to_check $(ls /etc/systemd/journald.conf.d/*)"
    fi

    for param in $PARAMS_TO_CHECK; do
        found=1
        for file in $files_to_check; do
            if grep -E "^[^#]*$param" "$file" >/dev/null; then
                found=0
                break
            fi
        done

        if [ "$found" -eq 1 ]; then
            info "$param not found in journald configuration"
            JOURNALD_LOG_ROTATION_VALID=1
        fi
    done

    if [ "$JOURNALD_LOG_ROTATION_VALID" -eq 0 ]; then
        ok "journald log rotation is fully configured"
    else
        crit "journald log rotation is not fully configured"
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$JOURNALD_LOG_ROTATION_VALID" -ne 0 ]; then
        info "Please review your journald configuration"
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
