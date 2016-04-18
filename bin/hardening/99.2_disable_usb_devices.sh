#!/bin/bash

#
# CIS Debian 7 Hardening /!\ Not in the Guide
#

#
# 99.2 Disable USB Devices
#

set -e # One error, it's over
set -u # One variable unset, it's over

USER='root'
PATTERN='ACTION=="add", SUBSYSTEMS=="usb", TEST=="authorized_default", ATTR{authorized_default}="0"' # We do test disabled by default, whitelist is up to you
FILES_TO_SEARCH='/etc/udev/rules.d/*'
FILE='/etc/udev/rules.d/10-CIS_99.2_usb_devices.sh'

# This function will be called if the script status is on enabled / audit mode
audit () {
    does_pattern_exists_in_file "$FILES_TO_SEARCH" "^$PATTERN"
    if [ $FNRET != 0 ]; then
        crit "$PATTERN not present in $FILES_TO_SEARCH"
    else
        ok "$PATTERN present in $FILES_TO_SEARCH"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    does_pattern_exists_in_file "$FILES_TO_SEARCH" "^$PATTERN"
    if [ $FNRET != 0 ]; then
        warn "$PATTERN not present in $FILES_TO_SEARCH"
        touch $FILE
        chmod 644 $FILE
        add_end_of_file $FILE '
# By default, disable all.
ACTION=="add", SUBSYSTEMS=="usb", TEST=="authorized_default", ATTR{authorized_default}="0"

# Enable hub devices.
ACTION=="add", ATTR{bDeviceClass}=="09", TEST=="authorized", ATTR{authorized}="1"

# Enables keyboard devices
ACTION=="add", ATTR{product}=="*[Kk]eyboard*", TEST=="authorized", ATTR{authorized}="1"

# PS2-USB converter
ACTION=="add", ATTR{product}=="*Thinnet TM*", TEST=="authorized", ATTR{authorized}="1"
'
    else
        ok "$PATTERN present in $FILES_TO_SEARCH"
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
    fi
fi 

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
[ -r $CIS_ROOT_DIR/lib/main.sh ] && . $CIS_ROOT_DIR/lib/main.sh
