#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 5.4.2.8 Ensure accounts without a valid login shell are locked (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Ensure accounts without a valid login shell are locked."

# Global state
ALIS_UNLOCKED_ACCOUNTS=""
ALIS_ALL_LOCKED=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    # Build regex of valid shells (excluding nologin)
    local valid_shells
    valid_shells="^($(awk -F/ '$NF != "nologin" {print}' /etc/shells | sed -rn '/^\//{ s,/,\\/,g;p }' | paste -s -d '|' -))$"

    # Find all non-root accounts without valid login shells
    local unlocked_accounts=""
    while IFS= read -r user; do
        # Check if account is locked
        local passwd_status
        passwd_status=$($SUDO_CMD passwd -S "$user" 2>/dev/null | awk '{print $2}' || true)
        if [ "$passwd_status" != "L" ] && [ "$passwd_status" != "LK" ]; then
            unlocked_accounts="${unlocked_accounts}${user} "
        fi
    done < <(awk -v pat="$valid_shells" -F: '($1 != "root" && $(NF) !~ pat) {print $1}' /etc/passwd)

    ALIS_UNLOCKED_ACCOUNTS="$unlocked_accounts"

    if [ -z "$ALIS_UNLOCKED_ACCOUNTS" ]; then
        ok "All accounts without valid login shells are locked"
        ALIS_ALL_LOCKED=0
    else
        crit "The following accounts without valid login shells are not locked: $ALIS_UNLOCKED_ACCOUNTS"
        ALIS_ALL_LOCKED=1
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$ALIS_ALL_LOCKED" -eq 0 ]; then
        ok "All accounts are already properly locked"
        return
    fi

    # Lock each unlocked account
    for user in $ALIS_UNLOCKED_ACCOUNTS; do
        info "Locking account: $user"
        passwd -l "$user"
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
if [ -z "${CIS_LIB_DIR}" ]; then
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
