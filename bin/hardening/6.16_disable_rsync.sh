#!/bin/bash

#
# CIS Debian 7 Hardening
# Authors : Thibault Dewailly, OVH <thibault.dewailly@corp.ovh.com>
#

#
# 6.16 Ensure rsync service is not enabled (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

PACKAGE='rsync'
RSYNC_DEFAULT_PATTERN='RSYNC_ENABLE=false'
RSYNC_DEFAULT_FILE='/etc/default/rsync'
RSYNC_DEFAULT_PATTERN_TO_SEARCH='RSYNC_ENABLE=true'

# This function will be called if the script status is on enabled / audit mode
audit () {
    is_pkg_installed $PACKAGE
    if [ $FNRET != 0 ]; then
        ok "$PACKAGE is not installed"
    else
        ok "$PACKAGE is installed, checking configuration"
        does_pattern_exists_in_file $RSYNC_DEFAULT_FILE "^$RSYNC_DEFAULT_PATTERN"
        if [ $FNRET != 0 ]; then
            crit "$RSYNC_DEFAULT_PATTERN not found in $RSYNC_DEFAULT_FILE"
        else
            ok "$RSYNC_DEFAULT_PATTERN found in $RSYNC_DEFAULT_FILE"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    is_pkg_installed $PACKAGE
    if [ $FNRET != 0 ]; then
        ok "$PACKAGE is not installed"
    else
        ok "$PACKAGE is installed, checking configuration"
        does_pattern_exists_in_file $RSYNC_DEFAULT_FILE "^$RSYNC_DEFAULT_PATTERN"
        if [ $FNRET != 0 ]; then
            warn "$RSYNC_DEFAULT_PATTERN not found in $RSYNC_DEFAULT_FILE, adding it"
            backup_file $RSYNC_DEFAULT_FILE
            replace_in_file $RSYNC_DEFAULT_FILE $RSYNC_DEFAULT_PATTERN_TO_SEARCH $RSYNC_DEFAULT_PATTERN
        else
            ok "$RSYNC_DEFAULT_PATTERN found in $RSYNC_DEFAULT_FILE"
        fi
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
