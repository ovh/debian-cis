#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure root is the only GID 0 account (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure root is the only GID 0 account."

# This function will be called if the script status is on enabled / audit mode
audit() {
    local gid0_accounts
    gid0_accounts=$(awk -F: '($4 == 0) { print $1 }' /etc/passwd)

    if [ "$gid0_accounts" = "root" ]; then
        ok "Only root account has GID 0"
    else
        crit "The following accounts have GID 0: $gid0_accounts"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    local gid0_accounts
    gid0_accounts=$(awk -F: '($4 == 0 && $1 != "root") { print $1 }' /etc/passwd)

    if [ -z "$gid0_accounts" ]; then
        ok "Only root account has GID 0, nothing to apply"
    else
        warn "The following accounts have GID 0 (besides root): $gid0_accounts"
        warn "Manual intervention required - review these accounts and assign different GIDs"
        crit "This check does not automatically modify GID 0 accounts for safety reasons"
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
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is ${CIS_LIB_DIR} in /etc/default/cis-hardening"
    exit 128
fi
