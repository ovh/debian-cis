#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 6.2.15 Ensure all groups in /etc/passwd exist in /etc/group (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="There is no group in /etc/passwd that is not in /etc/group."

ERRORS=0

# This function will be called if the script status is on enabled / audit mode
audit() {
    RESULT=$(cut -s -d: -f4 /etc/passwd | sort -u)
    for GROUP in $RESULT; do
        debug "Working on group $GROUP"
        if ! grep -q -P "^.*?:[^:]*:$GROUP:" /etc/group; then
            crit "Group $GROUP is referenced by /etc/passwd but does not exist in /etc/group"
            ERRORS=$((ERRORS + 1))
        fi
    done

    if [ "$ERRORS" = 0 ]; then
        ok "passwd and group Groups are consistent"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    info "Solving passwd and group consistency automatically may seriously harm your system, report only here"
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
