#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 6.2.10 Ensure users' dot files are not group or world writable (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Check user dot file permissions."

ERRORS=0

# This function will be called if the script status is on enabled / audit mode
audit() {
    for DIR in $(get_db passwd | grep -Ev '(root|halt|sync|shutdown)' | awk -F: '($7 != "/usr/sbin/nologin" && $7 != "/bin/false" && $7 !="/nonexistent" ) { print $6 }'); do
        debug "Working on $DIR"
        for FILE in "$DIR"/.[A-Za-z0-9]*; do
            if [ ! -h "$FILE" ] && [ -f "$FILE" ]; then
                FILEPERM=$(stat -c "%A" "$FILE")
                if [ "$(echo "$FILEPERM" | cut -c6)" != "-" ]; then
                    crit "Group Write permission set on FILE $FILE"
                    ERRORS=$((ERRORS + 1))
                fi
                if [ "$(echo "$FILEPERM" | cut -c9)" != "-" ]; then
                    crit "Other Write permission set on FILE $FILE"
                    ERRORS=$((ERRORS + 1))
                fi
            fi
        done
    done

    if [ "$ERRORS" = 0 ]; then
        ok "Dot file permission in users directories are correct"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    for DIR in $(get_db passwd | grep -Ev '(root|halt|sync|shutdown)' | awk -F: '($7 != "/usr/sbin/nologin" && $7 != "/bin/false" && $7 !="/nonexistent" ) { print $6 }'); do
        for FILE in "$DIR"/.[A-Za-z0-9]*; do
            if [ ! -h "$FILE" ] && [ -f "$FILE" ]; then
                FILEPERM=$(stat -c "%A" "$FILE")
                if [ "$(echo "$FILEPERM" | cut -c6)" != "-" ]; then
                    warn "Group Write permission set on FILE $FILE"
                    chmod g-w "$FILE"
                fi
                if [ "$(echo "$FILEPERM" | cut -c9)" != "-" ]; then
                    warn "Other Write permission set on FILE $FILE"
                    chmod o-w "$FILE"
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
