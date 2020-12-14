#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 6.2.13 Ensure users' .netrc Files are not group or world accessible (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure users' .netrc Files are not group or world accessible"

PERMISSIONS="600"
ERRORS=0

# This function will be called if the script status is on enabled / audit mode
audit() {
    for DIR in $(get_db passwd | grep -Ev '(root|halt|sync|shutdown)' | awk -F: '($7 != "/usr/sbin/nologin" && $7 != "/bin/false" && $7 !="/nonexistent" ) { print $6 }'); do
        debug "Working on $DIR"
        for FILE in $DIR/.netrc; do
            if [ ! -h "$FILE" ] && [ -f "$FILE" ]; then
                has_file_correct_permissions "$FILE" "$PERMISSIONS"
                if [ "$FNRET" = 0 ]; then
                    ok "$FILE has correct permissions"
                else
                    crit "$FILE permissions were not set to $PERMISSIONS"
                    ERRORS=$((ERRORS + 1))
                fi
            fi
        done
    done

    if [ "$ERRORS" = 0 ]; then
        ok "permission $PERMISSIONS set on .netrc users files"
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    for DIR in $(get_db passwd | grep -Ev '(root|halt|sync|shutdown)' | awk -F: '($7 != "/usr/sbin/nologin" && $7 != "/bin/false" && $7 !="/nonexistent" ) { print $6 }'); do
        debug "Working on $DIR"
        for FILE in $DIR/.netrc; do
            if [ ! -h "$FILE" ] && [ -f "$FILE" ]; then
                has_file_correct_permissions "$FILE" "$PERMISSIONS"
                if [ "$FNRET" = 0 ]; then
                    ok "$FILE has correct permissions"
                else
                    warn "$FILE permissions were not set to $PERMISSIONS"
                    chmod 600 "$FILE"
                fi
            fi
        done
    done
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
