#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 10.3 Set Default Group for root Account (Scored)
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
        crit "Root group GID should be $EXPECTED_GID"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    if [ $(grep "^root:" /etc/passwd | cut -f4 -d:) = 0 ]; then
        ok "Root group GID is $EXPECTED_GID"
    else
        warn "Root group GID is not $EXPECTED_GID"
        usermod -g $EXPECTED_GID $USER
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
    if [ -z $CIS_ROOT_DIR ]; then
        echo "No CIS_ROOT_DIR variable, aborting"
        exit 128
    fi
fi 

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
[ -r $CIS_ROOT_DIR/lib/main.sh ] && . $CIS_ROOT_DIR/lib/main.sh
