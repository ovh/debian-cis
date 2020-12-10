#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 2.2.16 Ensure rsync service is not enabled (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure rsync service is not enabled."
# shellcheck disable=2034
HARDENING_EXCEPTION=rsync

PACKAGE='rsync'
RSYNC_DEFAULT_PATTERN='RSYNC_ENABLE=false'
RSYNC_DEFAULT_FILE='/etc/default/rsync'
RSYNC_DEFAULT_PATTERN_TO_SEARCH='RSYNC_ENABLE=true'

# This function will be called if the script status is on enabled / audit mode
audit() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        ok "$PACKAGE is not installed"
    else
        ok "$PACKAGE is installed, checking configuration"
        does_pattern_exist_in_file "$RSYNC_DEFAULT_FILE" "^$RSYNC_DEFAULT_PATTERN"
        if [ "$FNRET" != 0 ]; then
            crit "$RSYNC_DEFAULT_PATTERN not found in $RSYNC_DEFAULT_FILE"
        else
            ok "$RSYNC_DEFAULT_PATTERN found in $RSYNC_DEFAULT_FILE"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        ok "$PACKAGE is not installed"
    else
        ok "$PACKAGE is installed, checking configuration"
        does_pattern_exist_in_file "$RSYNC_DEFAULT_FILE" "^$RSYNC_DEFAULT_PATTERN"
        if [ "$FNRET" != 0 ]; then
            warn "$RSYNC_DEFAULT_PATTERN not found in $RSYNC_DEFAULT_FILE, adding it"
            backup_file "$RSYNC_DEFAULT_FILE"
            replace_in_file "$RSYNC_DEFAULT_FILE" "$RSYNC_DEFAULT_PATTERN_TO_SEARCH" "$RSYNC_DEFAULT_PATTERN"
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
if [ -r /etc/default/cis-hardening ]; then
    # shellcheck source=../../debian/default
    . /etc/default/cis-hardening
fi
if [ -z "$CIS_ROOT_DIR" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_ROOT_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r "$CIS_ROOT_DIR"/lib/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "$CIS_ROOT_DIR"/lib/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_ROOT_DIR in /etc/default/cis-hardening"
    exit 128
fi
