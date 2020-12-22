#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 4.2.3 Ensure permissions on all logfiles are configured (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Check permissions on logs (other has no permissions on any files and group does not have write or execute permissions on any file)"

DIR='/var/log'
PERMISSIONS='640'

# This function will be called if the script status is on enabled / audit mode
audit() {
    ERRORS=0
    for FILE in $($SUDO_CMD find $DIR -type f); do
        has_file_correct_permissions "$FILE" "$PERMISSIONS"
        if [ "$FNRET" = 0 ]; then
            ok "$FILE permissions were set to $PERMISSIONS"
        else
            ERRORS=$((ERRORS + 1))
            crit "$FILE permissions were not set to $PERMISSIONS"
        fi
    done

    if [ "$ERRORS" = 0 ]; then
        ok "Logs in $DIR have correct permissions"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    ERRORS=0
    for FILE in $($SUDO_CMD find $DIR -type f); do
        has_file_correct_permissions "$FILE" "$PERMISSIONS"
        if [ "$FNRET" = 0 ]; then
            ok "$FILE permissions were set to $PERMISSIONS"
        else
            warn "fixing $DIR logs ownership to $PERMISSIONS"
            chmod 0"$PERMISSIONS" "$FILE"
        fi
    done

    if [ "$ERRORS" = 0 ]; then
        ok "Logs in $DIR have correct permissions"
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
if [ -z "$CIS_ROOT_DIR" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_ROOT_DIR variable, aborting."
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
