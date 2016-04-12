#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 5.1.5 Ensure talk client is not installed (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

PACKAGES='talk inetutils-talk'

# This function will be called if the script status is on enabled / audit mode
audit () {
    for PACKAGE in $PACKAGES; do
        is_pkg_installed $PACKAGE
        if [ $FNRET = 0 ]; then
            crit "$PACKAGE is installed"
        else
            ok "$PACKAGE is absent"
        fi
    done
}

# This function will be called if the script status is on enabled mode
apply () {
    for PACKAGE in $PACKAGES; do
        is_pkg_installed $PACKAGE
        if [ $FNRET = 0 ]; then
            warn "$PACKAGE is installed, purging"
            apt-get purge $PACKAGE -y
        else
            ok "$PACKAGE is absent"
        fi
    done
}

# This function will check config parameters required
check_config() {
    :
}

# Source Root Dir Parameter
if [ ! -r /etc/default/cis-hardenning ]; then
    echo "There is no /etc/default/cis-hardenning file, cannot source CIS_ROOT_DIR variable, aborting"
    exit 128
else
    . /etc/default/cis-hardenning
    if [ -z $CIS_ROOT_DIR ]; then
        echo "No CIS_ROOT_DIR variable, aborting"
    fi
fi 

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
[ -r $CIS_ROOT_DIR/lib/main.sh ] && . $CIS_ROOT_DIR/lib/main.sh
