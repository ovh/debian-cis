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

# Ask APT to parse its configured sources, including deb822 .sources files.
# --no-release-info includes targets even before package metadata is downloaded.
# This checks configured index targets, not repository reachability or trust.
audit() {
    local targets
    # URI is an APT format placeholder, not a shell expansion.
    # shellcheck disable=SC2016
    if ! targets=$(apt-get indextargets --no-release-info --format '$(URI)'); then
        crit "Unable to read APT repository configuration"
    elif [ -z "$targets" ]; then
        crit "No active APT repository index targets are configured"
    else
        ok "APT repository index targets are configured; verify repository policy manually"
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
