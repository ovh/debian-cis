#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 6.2.6 Ensure root is the only UID 0 account (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
# shellcheck disable=2034
DESCRIPTION="Verify root is the only UID 0 account."
EXCEPTIONS=""

FILE='/etc/passwd'
RESULT=''

# This function will be called if the script status is on enabled / audit mode
audit() {
    info "Checking if accounts have uid 0"
    RESULT=$(awk -F: '($3 == 0 && $1!="root" ) { print $1 }' "$FILE")
    FOUND_EXCEPTIONS=""
    for ACCOUNT in $RESULT; do
        debug "Account : $ACCOUNT"
        debug "Exceptions : $EXCEPTIONS"
        debug "echo \"$EXCEPTIONS\" | grep -qw $ACCOUNT"
        if echo "$EXCEPTIONS" | grep -qw "$ACCOUNT"; then
            debug "$ACCOUNT is confirmed as an exception"
            # shellcheck disable=SC2001
            RESULT=$(sed "s!$ACCOUNT!!" <<<"$RESULT")
            FOUND_EXCEPTIONS="$FOUND_EXCEPTIONS $ACCOUNT"
        else
            debug "$ACCOUNT not found in exceptions"
        fi
    done
    if [ -n "$RESULT" ]; then
        crit "Some accounts have uid 0: $(tr '\n' ' ' <<<"$RESULT")"
    else
        ok "No account with uid 0 appart from root ${FOUND_EXCEPTIONS:+and configured exceptions:}$FOUND_EXCEPTIONS"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    info "Removing accounts with uid 0 may seriously harm your system, report only here"
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit
# Put here valid accounts with uid 0 separated by spaces
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
