#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 5.1.8 Ensure at/cron is restricted to authorized users (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Restrict at/cron to authorized users."

FILES_ABSENT='/etc/cron.deny /etc/at.deny'
FILES_PRESENT='/etc/cron.allow /etc/at.allow'
PERMISSIONS='644'
PERMISSIONSOK='644 640 600 440 400'
USER='root'
GROUP='root'

# This function will be called if the script status is on enabled / audit mode
audit() {
    for FILE in $FILES_ABSENT; do
        does_file_exist "$FILE"
        if [ "$FNRET" = 0 ]; then
            crit "$FILE exists"
        else
            ok "$FILE is absent"
        fi
    done
    for FILE in $FILES_PRESENT; do
        does_file_exist "$FILE"
        if [ "$FNRET" != 0 ]; then
            crit "$FILE is absent, should exist"
        else
            has_file_correct_ownership "$FILE" "$USER" "$GROUP"
            if [ "$FNRET" = 0 ]; then
                ok "$FILE has correct ownership"
            else
                crit "$FILE ownership was not set to $USER:$GROUP"
            fi
            has_file_one_of_permissions "$FILE" "$PERMISSIONSOK"
            if [ "$FNRET" = 0 ]; then
                ok "$FILE has correct permissions"
            else
                crit "$FILE permissions were not set to $PERMISSIONS"
            fi
        fi
    done
}

# This function will be called if the script status is on enabled mode
apply() {
    for FILE in $FILES_ABSENT; do
        does_file_exist "$FILE"
        if [ "$FNRET" = 0 ]; then
            warn "$FILE exists"
            rm "$FILE"
        else
            ok "$FILE is absent"
        fi
    done
    for FILE in $FILES_PRESENT; do
        does_file_exist "$FILE"
        if [ "$FNRET" != 0 ]; then
            warn "$FILE is absent, fixing (touch)"
            touch "$FILE"
        fi
        has_file_correct_ownership "$FILE" "$USER" "$GROUP"
        if [ "$FNRET" = 0 ]; then
            ok "$FILE has correct ownership"
        else
            warn "fixing $FILE ownership to $USER:$GROUP"
            chown "$USER":"$GROUP" "$FILE"
        fi
        has_file_one_of_permissions "$FILE" "$PERMISSIONSOK"
        if [ "$FNRET" = 0 ]; then
            ok "$FILE has correct permissions"
        else
            warn "$FILE permissions were not set to $PERMISSIONS"
            chmod 0"$PERMISSIONS" "$FILE"
        fi
    done
}

# This function will check config parameters required
check_config() {
    does_user_exist "$USER"
    if [ "$FNRET" != 0 ]; then
        crit "$USER does not exist"
        exit 128
    fi
    does_group_exist "$GROUP"
    if [ "$FNRET" != 0 ]; then
        crit "$GROUP does not exist"
        exit 128
    fi
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
