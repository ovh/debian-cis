#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# Hardening script skeleton replace this line with proper point treated
#

set -e # One error, it's over
set -u # One variable unset, it's over

# This function will be called if the script status is on enabled / audit mode
audit () {
    :
}

# This function will be called if the script status is on enabled mode
apply () {
    :
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

LONG_SCRIPT_NAME=$(basename $0)
SCRIPT_NAME=${LONG_SCRIPT_NAME%.sh}
# Variable initialization, to avoid crash
status=""
params=""

[ -r $CIS_ROOT_DIR/lib/constants.sh ] && . $CIS_ROOT_DIR/lib/constants.sh
[ -r $CIS_ROOT_DIR/lib/utils.sh     ] && . $CIS_ROOT_DIR/lib/utils.sh
[ -r $CIS_ROOT_DIR/lib/common.sh    ] && . $CIS_ROOT_DIR/lib/common.sh
[ -r $CIS_ROOT_DIR/etc/hardening.cfg ] && . $CIS_ROOT_DIR/etc/hardening.cfg
# Source general configuration file and Specific configuration file if exist

[ -r $CIS_ROOT_DIR/etc/conf.d/$SCRIPT_NAME.cfg ] && . $CIS_ROOT_DIR/etc/conf.d/$SCRIPT_NAME.cfg

logger "Working on $SCRIPT_NAME"

if [ -z $status ]; then
    logger "Could not find status variable for $SCRIPT_NAME, considered as disabled"
    exit 0
fi

case $status in
    enabled | true ) 
        audit $params # Perform audit
        apply $params # Perform hardening
        ;;
    audit )
        audit $params # Perform audit
        ;;
    disabled | false )
        logger "$SCRIPT_NAME is disabled, ignoring"
        ;;
    *)
        logger "Wrong value for status : $status. Must be [ enabled | true | audit | disabled | false ]"
        ;;
esac
