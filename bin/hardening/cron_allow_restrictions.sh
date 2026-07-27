#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure cron is restricted to authorized users (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure cron is restricted to authorized users."

PACKAGE='cron'
CRON_ALLOW='/etc/cron.allow'
CRON_DENY='/etc/cron.deny'
PERMISSIONS='640'
USER='root'
GROUP='root'

# Global state
CRON_ALLOW_RESTR_INSTALLED=1
CRON_ALLOW_RESTR_FILE_OK=1
CRON_DENY_FILE_OK=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" -ne 0 ]; then
        ok "$PACKAGE is not installed, cron restrictions not applicable"
        CRON_ALLOW_RESTR_INSTALLED=0
        return
    fi
    ok "$PACKAGE is installed"

    # Check /etc/cron.allow
    if [ ! -f "$CRON_ALLOW" ]; then
        crit "$CRON_ALLOW does not exist"
        CRON_ALLOW_RESTR_FILE_OK=0
    else
        has_file_correct_ownership "$CRON_ALLOW" "$USER" "$GROUP"
        if [ "$FNRET" -ne 0 ]; then
            crit "$CRON_ALLOW ownership is not $USER:$GROUP"
            CRON_ALLOW_RESTR_FILE_OK=0
        else
            ok "$CRON_ALLOW has correct ownership"
        fi

        has_file_correct_permissions "$CRON_ALLOW" "$PERMISSIONS"
        if [ "$FNRET" -ne 0 ]; then
            crit "$CRON_ALLOW permissions are not $PERMISSIONS"
            CRON_ALLOW_RESTR_FILE_OK=0
        else
            ok "$CRON_ALLOW has correct permissions"
        fi
    fi

    # Check /etc/cron.deny - should not exist or have restrictive permissions
    if [ -f "$CRON_DENY" ]; then
        warn "$CRON_DENY exists, it should be removed when using $CRON_ALLOW"
        CRON_DENY_FILE_OK=0
    else
        ok "$CRON_DENY does not exist"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$CRON_ALLOW_RESTR_INSTALLED" -eq 0 ]; then
        ok "$PACKAGE is not installed, nothing to apply"
        return
    fi

    # Create/fix cron.allow
    if [ "$CRON_ALLOW_RESTR_FILE_OK" -eq 0 ]; then
        if [ ! -f "$CRON_ALLOW" ]; then
            info "Creating $CRON_ALLOW"
            touch "$CRON_ALLOW"
        fi

        info "Setting ownership and permissions on $CRON_ALLOW"
        chown "$USER":"$GROUP" "$CRON_ALLOW"
        chmod "$PERMISSIONS" "$CRON_ALLOW"
    else
        ok "$CRON_ALLOW is correctly configured"
    fi

    # Remove cron.deny if it exists
    if [ "$CRON_DENY_FILE_OK" -eq 0 ]; then
        if [ -f "$CRON_DENY" ]; then
            info "Removing $CRON_DENY"
            rm -f "$CRON_DENY"
        fi
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
if [ -z "${CIS_LIB_DIR}" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_LIB_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r "${CIS_LIB_DIR}"/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "${CIS_LIB_DIR}"/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is ${CIS_LIB_DIR} in /etc/default/cis-hardening"
    exit 128
fi
