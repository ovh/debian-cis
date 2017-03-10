#!/bin/bash

#
# CIS Debian 7/8 Hardening
#

#
# 7.7 Ensure Firewall is active (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# Quick note here : CIS recommends your iptables rules to be persistent. 
# Do as you want, but this script does not handle this

PACKAGE='iptables'

# This function will be called if the script status is on enabled / audit mode
audit () {
    is_pkg_installed $PACKAGE
    if [ $FNRET != 0 ]; then
        crit "$PACKAGE is not installed!"
    else
        ok "$PACKAGE is installed"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
        is_pkg_installed $PACKAGE
        if [ $FNRET = 0 ]; then
            ok "$PACKAGE is installed"
        else
            crit "$PACKAGE is absent, installing it"
            apt_install $PACKAGE
        fi
}

# This function will check config parameters required
check_config() {
    :
}

# Source Root Dir Parameter
if [ ! -r /etc/default/cis-hardening ]; then
    echo "There is no /etc/default/cis-hardening file, cannot source CIS_ROOT_DIR variable, aborting"
    exit 128
else
    . /etc/default/cis-hardening
    if [ -z ${CIS_ROOT_DIR:-} ]; then
        echo "No CIS_ROOT_DIR variable, aborting"
        exit 128
    fi
fi 

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r $CIS_ROOT_DIR/lib/main.sh ]; then
    . $CIS_ROOT_DIR/lib/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_ROOT_DIR in /etc/default/cis-hardening"
    exit 128
fi
