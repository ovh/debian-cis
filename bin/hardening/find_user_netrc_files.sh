#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure no users have .netrc files (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="There is no user .netrc files."

ERRORS=0
FILENAME='.netrc'

# This function will be called if the script status is on enabled / audit mode
audit() {
    for DIR in $(get_db passwd | grep -Ev '(root|halt|sync|shutdown)' | awk -F: '($7 != "/usr/sbin/nologin" && $7 != "/bin/false" && $7 !="/nonexistent" ) { print $6 }'); do
        debug "Working on $DIR"
        for FILE in $DIR/$FILENAME; do
            if [ ! -h "$FILE" ] && [ -f "$FILE" ]; then
                crit "$FILE present"
                ERRORS=$((ERRORS + 1))
            fi
        done
    done

    if [ "$ERRORS" = 0 ]; then
        ok "No $FILENAME present in users home directory"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    info "If the audit returns something, please check with the user why he has this file"
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
