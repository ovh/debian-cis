#!/bin/bash

#
# CIS Debian 7 Hardening
# Authors : Thibault Dewailly, OVH <thibault.dewailly@corp.ovh.com>
#

#
# 10.1.3 Set Password Expiring Warning Days (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

USER='root'
EXPECTED_GID='0'

# This function will be called if the script status is on enabled / audit mode
audit () {
    if [ $(grep "^root:" /etc/passwd | cut -f4 -d:) = 0 ]; then
        ok "Root group has GID $EXPECTED_GID"
    else
        crit "Root group has not GID $EXPECTED_GID"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    if [ $(grep "^root:" /etc/passwd | cut -f4 -d:) = 0 ]; then
        ok "Root group has GID $EXPECTED_GID"
    else
        warn "Root group has not GID $EXPECTED_GID"
        usermod -g $EXPECTED_GID $USER
    fi
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
