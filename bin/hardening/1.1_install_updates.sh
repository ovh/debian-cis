#!/bin/bash

#
# CIS Debian 7/8 Hardening
#

#
# 1.1 Install Updates, Patches and Additional Security Software (Not Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

HARDENING_LEVEL=3
DESCRIPTION="Install updates, patches and additional secutiry software."

# This function will be called if the script status is on enabled / audit mode
audit () {
    info "Checking if apt needs an update"
    apt_update_if_needed 
    info "Fetching upgrades ..."
    apt_check_updates "CIS_APT"
    if [ $FNRET -gt 0 ]; then
        crit "$RESULT"
        FNRET=1
    else
        ok "No upgrades available"
        FNRET=0
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    if [ $FNRET -gt 0 ]; then 
        info "Applying Upgrades..."
        DEBIAN_FRONTEND='noninteractive' apt-get -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' upgrade -y
    else
        ok "No Upgrades to apply"
    fi
}

# This function will check config parameters required
check_config() {
    # No parameters for this function
    :
}

# Source Root Dir Parameter
if [ -r /etc/default/cis-hardening ]; then
    . /etc/default/cis-hardening
fi
if [ -z "$CIS_ROOT_DIR" ]; then
     echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
     echo "Cannot source CIS_ROOT_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r $CIS_ROOT_DIR/lib/main.sh ]; then
    . $CIS_ROOT_DIR/lib/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_ROOT_DIR in /etc/default/cis-hardening"
    exit 128
fi
