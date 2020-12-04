#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 6.2.17 Ensure no duplicate GIDs exist (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure no duplicate GIDs exist"

ERRORS=0

# This function will be called if the script status is on enabled / audit mode
audit() {
    RESULT=$(get_db group | cut -f3 -d":" | sort -n | uniq -c | awk '{print $1":"$2}')
    for LINE in $RESULT; do
        debug "Working on line $LINE"
        OCC_NUMBER=$(awk -F: '{print $1}' <<<"$LINE")
        GROUPID=$(awk -F: '{print $2}' <<<"$LINE")
        if [ "$OCC_NUMBER" -gt 1 ]; then
            GROUP=$(awk -F: '($3 == n) { print $1 }' n="$GROUPID" /etc/group | xargs)
            ERRORS=$((ERRORS + 1))
            crit "Duplicate GID ($GROUPID): ${GROUP}"
        fi
    done

    if [ "$ERRORS" = 0 ]; then
        ok "No duplicate GIDs"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    info "Editing automatically gids may seriously harm your system, report only here"
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
