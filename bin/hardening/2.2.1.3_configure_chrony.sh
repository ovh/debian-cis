#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 2.2.1.3 Ensure chrony is configured (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Configure Network Time Protocol (ntp). Check restrict parameters and ntp daemon runs ad unprivileged user."
# shellcheck disable=2034
HARDENING_EXCEPTION=ntp

PACKAGE=chrony
CONF_DEFAULT_PATTERN='^(server|pool)'
CONF_FILE='/etc/chrony/chrony.conf'

# This function will be called if the script status is on enabled / audit mode
audit() {
    does_pattern_exist_in_file "$CONF_FILE" "$CONF_DEFAULT_PATTERN"
    if [ "$FNRET" != 0 ]; then
        crit "$CONF_DEFAULT_PATTERN not found in $CONF_FILE"
    else
        ok "$CONF_DEFAULT_PATTERN found in $CONF_FILE"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    :
}

# This function will check config parameters required
check_config() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        warn "$PACKAGE is not installed, not handling configuration"
        exit 2
    fi
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
