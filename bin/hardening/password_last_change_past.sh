#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure all users last password change date is in the past (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Check that user last password change date is in the past."

PASSWD_LAST_CHANGE_PAST_ERROR_COUNT=0
PASSWD_LAST_CHANGE_PAST_FUTURE_USERS=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    local l_user
    local l_lastchg
    local l_now_days

    PASSWD_LAST_CHANGE_PAST_ERROR_COUNT=0
    PASSWD_LAST_CHANGE_PAST_FUTURE_USERS=""

    if ! $SUDO_CMD cat /etc/shadow >/dev/null 2>&1; then
        crit "Cannot read /etc/shadow to verify users password change dates"
        return
    fi

    l_now_days=$(($(date +%s) / 86400))

    while IFS= read -r l_user; do
        l_lastchg=$($SUDO_CMD grep -E "^${l_user}:" /etc/shadow 2>/dev/null | cut -d: -f3 | head -n 1 || true)

        # Empty lastchg means no usable date.
        if [ -z "$l_lastchg" ]; then
            continue
        fi

        if ! [[ "$l_lastchg" =~ ^[0-9]+$ ]]; then
            PASSWD_LAST_CHANGE_PAST_ERROR_COUNT=$((PASSWD_LAST_CHANGE_PAST_ERROR_COUNT + 1))
            crit "User: $l_user has an invalid last password change value in /etc/shadow: $l_lastchg"
            continue
        fi

        if [ "$l_lastchg" -gt "$l_now_days" ]; then
            PASSWD_LAST_CHANGE_PAST_ERROR_COUNT=$((PASSWD_LAST_CHANGE_PAST_ERROR_COUNT + 1))
            PASSWD_LAST_CHANGE_PAST_FUTURE_USERS="$PASSWD_LAST_CHANGE_PAST_FUTURE_USERS $l_user"
            crit "User: $l_user last password change is in the future (day index $l_lastchg > $l_now_days)"
        fi
    done < <($SUDO_CMD cat /etc/shadow | awk -F: '$2~/^\$.+$/ {print $1}')

    if [ "$PASSWD_LAST_CHANGE_PAST_ERROR_COUNT" -eq 0 ]; then
        ok "All users last password change dates are in the past"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$PASSWD_LAST_CHANGE_PAST_ERROR_COUNT" -eq 0 ]; then
        ok "All users last password change dates are in the past"
        return
    fi

    info "Manual remediation required: review affected users and set a valid last password change date"
    if [ -n "$PASSWD_LAST_CHANGE_PAST_FUTURE_USERS" ]; then
        warn "Users with future last password change date:$PASSWD_LAST_CHANGE_PAST_FUTURE_USERS"
    fi
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
