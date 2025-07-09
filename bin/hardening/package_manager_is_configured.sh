#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure package manager repositories are configured (Manual)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Ensure apt has source list"

# CIS recommends to execute "apt-cache policy" to ensure the configuration is correct
# this is not convenient to test, we check the presence of sources list in /var/lib/apt/lists/
APT_LIB_PATH="/var/lib/apt/lists/"
# files that are going to be present anyway
MANDATORY_FILES="lock auxfiles partial"

# This function will be called if the script status is on enabled / audit mode
audit() {
    apt update >/dev/null 2>&1 || true

    # shellcheck disable=2012
    if [ "$(ls "$APT_LIB_PATH" | wc -l)" -ne "$(wc -w <<<"$MANDATORY_FILES")" ]; then
        ok "apt package manager is configured"
    else
        crit "there is no source file, apt is not configured"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    warn "This recommendation can only be resolved manually"
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
