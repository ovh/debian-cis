#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 4.4 Disable Prelink (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

PACKAGE='prelink'

# This function will be called if the script status is on enabled / audit mode
audit () {
    is_pkg_installed $PACKAGE
    if [ $FNRET = 0 ]; then
        crit "$PACKAGE is installed !"
    else
        ok "$PACKAGE is absent"
    fi
    :
}

# This function will be called if the script status is on enabled mode
apply () {
    is_pkg_installed $PACKAGE
    if [ $FNRET = 0 ]; then
        crit "$PACKAGE is installed, purging it"
        /usr/sbin/prelink -ua
        apt-get purge $PACKAGE -y
    else
        ok "$PACKAGE is absent"
    fi
    :
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
