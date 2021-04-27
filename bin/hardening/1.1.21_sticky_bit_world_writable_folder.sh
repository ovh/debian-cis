#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 1.1.21 Ensure sticky bit is set on all world-writable directories (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Set sticky bit on world writable directories to prevent users from deleting or renaming files that are not owned by them."

# This function will be called if the script status is on enabled / audit mode
audit() {
    info "Checking if setuid is set on world writable Directories"
    FS_NAMES=$(df --local -P | awk '{if (NR!=1) print $6}')
    # shellcheck disable=SC2086
    RESULT=$($SUDO_CMD find $FS_NAMES -xdev -type d \( -perm -0002 -a ! -perm -1000 \) -print 2>/dev/null)
    IFS_BAK=$IFS
    IFS=$'\n'
    for LINE in $RESULT; do
        debug "line : $LINE"
        if echo "$EXCEPTIONS" | grep -q "$LINE"; then
            debug "$LINE is confirmed as an exception"
            # shellcheck disable=SC2001
            RESULT=$(sed "s!$LINE!!" <<<"$RESULT")
        else
            debug "$LINE not found in exceptions"
        fi
    done
    IFS=$IFS_BAK
    if [ -n "$RESULT" ]; then
        crit "Some world writable directories are not on sticky bit mode!"
        # shellcheck disable=SC2001
        FORMATTED_RESULT=$(sed "s/ /\n/g" <<<"$RESULT" | sort | uniq | tr '\n' ' ')
        crit "$FORMATTED_RESULT"
    else
        ok "All world writable directories have a sticky bit"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    RESULT=$(df --local -P | awk '{if (NR!=1) print $6}' | xargs -I '{}' find '{}' -xdev -type d \( -perm -0002 -a ! -perm -1000 \) -print 2>/dev/null)
    IFS_BAK=$IFS
    IFS=$'\n'
    for LINE in $RESULT; do
        debug "line : $LINE"
        if echo "$EXCEPTIONS" | grep -q "$ACCOUNT"; then
            debug "$ACCOUNT is confirmed as an exception"
            # shellcheck disable=SC2001
            RESULT=$(sed "s!$LINE!!" <<<"$RESULT")
        else
            debug "$ACCOUNT not found in exceptions"
        fi
    done
    IFS=$IFS_BAK
    if [ -n "$RESULT" ]; then
        warn "Setting sticky bit on world writable directories"
        df --local -P | awk '{if (NR!=1) print $6}' | xargs -I '{}' find '{}' -xdev -type d -perm -0002 2>/dev/null | xargs chmod a+t
    else
        ok "All world writable directories have a sticky bit, nothing to apply"
    fi
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit
# Put here your exceptions separated by spaces
EXCEPTIONS=""
EOF
}

# This function will check config parameters required
check_config() {
    if [ -z "$EXCEPTIONS" ]; then
        EXCEPTIONS="@"
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
