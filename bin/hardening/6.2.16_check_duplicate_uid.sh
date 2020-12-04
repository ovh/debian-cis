#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 6.2.16 Ensure no duplicate UIDs exist (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure no duplicate UIDs exist"
EXCEPTIONS=""

ERRORS=0

# This function will be called if the script status is on enabled / audit mode
audit() {
    RESULT=$(get_db passwd | cut -f3 -d":" | sort -n | uniq -c | awk '{print $1":"$2}')
    FOUND_EXCEPTIONS=""
    for LINE in $RESULT; do
        debug "Working on line $LINE"
        OCC_NUMBER=$(awk -F: '{print $1}' <<<"$LINE")
        USERID=$(awk -F: '{print $2}' <<<"$LINE")
        if [ "$OCC_NUMBER" -gt 1 ]; then
            USERS=$(awk -F: '($3 == n) { print $1 }' n="$USERID" /etc/passwd | xargs)
            ID_NAMES="($USERID): ${USERS}"
            if echo "$EXCEPTIONS" | grep -qw "$USERID"; then
                debug "$USERID is confirmed as an exception"
                FOUND_EXCEPTIONS="$FOUND_EXCEPTIONS $ID_NAMES"
            else
                ERRORS=$((ERRORS + 1))
                crit "Duplicate UID $ID_NAMES"
            fi
        fi
    done

    if [ "$ERRORS" = 0 ]; then
        ok "No duplicate UIDs${FOUND_EXCEPTIONS:+ apart from configured exceptions:}${FOUND_EXCEPTIONS}"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    info "Editing automatically uids may seriously harm your system, report only here"
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit
# Put here valid UIDs for which multiple usernames are accepted
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
