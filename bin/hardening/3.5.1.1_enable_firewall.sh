#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 3.5.1.1 Ensure Firewall is active (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure firewall is active (either nftables or iptables is installed, does not check for its configuration)."

# Note: CIS recommends your iptables rules to be persistent.
# Do as you want, but this script does not handle this

PACKAGES='iptables nftables'

# This function will be called if the script status is on enabled / audit mode
audit() {
    FOUND=false
    for PACKAGE in $PACKAGES; do
        is_pkg_installed "$PACKAGE"
        if [ "$FNRET" = 0 ]; then
            ok "$PACKAGE provides firewalling feature"
            FOUND=true
        fi
    done
    if [ "$FOUND" = false ]; then
        crit "None of the following firewall packages are installed: $PACKAGES"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    for PACKAGE in $PACKAGES; do
        is_pkg_installed "$PACKAGE"
        if [ "$FNRET" = 0 ]; then
            ok "$PACKAGE provides firewalling feature"
            FOUND=true
        fi
    done
    if [ "$FOUND" = false ]; then
        crit "None of the following firewall packages are installed: $PACKAGES, installing them"
        # FIXME : iptables is hardcoded, we will have to change this in the future
        # This will install nftables and iptables
        apt_install "iptables"
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
