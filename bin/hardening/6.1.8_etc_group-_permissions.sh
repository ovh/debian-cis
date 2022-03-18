#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 6.1.8 Ensure permissions on /etc/group- are configured (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Check 600 permissions and root:root ownership on /etc/group-"

FILE='/etc/group-'
PERMISSIONS='600'
PERMISSIONSOK='644 640 600'
USER='root'
GROUP='root'

# This function will be called if the script status is on enabled / audit mode
audit() {
    does_file_exist "$FILE"
    if [ "$FNRET" != 0 ]; then
        ok "$FILE does not exist"
    else
        has_file_one_of_permissions "$FILE" "$PERMISSIONSOK"
        if [ "$FNRET" = 0 ]; then
            ok "$FILE has correct permissions"
        else
            crit "$FILE permissions were not set to $PERMISSIONS"
        fi
        has_file_correct_ownership "$FILE" "$USER" "$GROUP"
        if [ "$FNRET" = 0 ]; then
            ok "$FILE has correct ownership"
        else
            crit "$FILE ownership was not set to $USER:$GROUP"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    does_file_exist "$FILE"
    if [ "$FNRET" != 0 ]; then
        ok "$FILE does not exist"
    else
        has_file_correct_permissions "$FILE" "$PERMISSIONS"
        if [ "$FNRET" = 0 ]; then
            ok "$FILE has correct permissions"
        else
            info "fixing $FILE permissions to $PERMISSIONS"
            chmod 0"$PERMISSIONS" "$FILE"
        fi
        has_file_correct_ownership "$FILE" "$USER" "$GROUP"
        if [ "$FNRET" = 0 ]; then
            ok "$FILE has correct ownership"
        else
            info "fixing $FILE ownership to $USER:$GROUP"
            chown "$USER":"$GROUP" "$FILE"
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
