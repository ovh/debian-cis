#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 6.2.20 Ensure shadow group is empty (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="There is no user in shadow group (that can read /etc/shadow file)."

FILEGROUP='/etc/group'
PATTERN='^shadow:x:[[:digit:]]+:'

# This function will be called if the script status is on enabled / audit mode
audit() {
    does_pattern_exist_in_file "$FILEGROUP" "$PATTERN"
    if [ "$FNRET" = 0 ]; then
        info "shadow group exists"
        RESULT=$(grep -E "$PATTERN" $FILEGROUP | cut -d: -f4)
        GROUPID=$(getent group shadow | cut -d: -f3)
        debug "$RESULT $GROUPID"
        if [ -n "$RESULT" ]; then
            crit "Some users belong to shadow group: $RESULT"
        else
            ok "No user belongs to shadow group"
        fi

        info "Checking if a user has $GROUPID as primary group"
        RESULT=$(awk -F: '($4 == shadowid) { print $1 }' shadowid="$GROUPID" /etc/passwd)
        if [ -n "$RESULT" ]; then
            crit "Some users have shadow id as their primary group: $RESULT"
        else
            ok "No user has shadow id as their primary group"
        fi
    else
        crit "shadow group doesn't exist"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    info "Editing automatically users/groups may seriously harm your system, report only here"
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
