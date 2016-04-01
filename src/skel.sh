#!/bin/bash

#
# CIS Debian 7 Hardening
#


#
# Hardening script skeleton replace this line with proper point treated
#

# This function will be called if the script status is ont enabled / audit mode
audit () {

}

# This function will be called if the script status is on enabled mode
apply () {

}

# Environment Sanitizing
export PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

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

SCRIPT_NAME=$(basename $0)

# Source general configuration file and Specific configuration file if exist

[ -r $ROOT_DIR/etc/hardening.cfg ] && . $ROOT_DIR/etc/hardening.cfg
[ -r $ROOT_DIR/etc/hardening/$SCRIPT_NAME ] && . $ROOT_DIR/etc/hardening/$SCRIPT_NAME


