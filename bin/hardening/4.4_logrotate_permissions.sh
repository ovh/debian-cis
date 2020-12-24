#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 4.4 Ensure logrotate assigns approriate permissions (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Configure logrotate to assign appropriate permissions."

FILE="/etc/logrotate.conf"
PATTERN="^\s*create\s+\S+"
PERMISSIONS=0640

# This function will be called if the script status is on enabled / audit mode
audit() {
    does_pattern_exist_in_file "$FILE" "$PATTERN"
    if [ "$FNRET" != 0 ]; then
        crit "Logrotate permissions are not configured"
    else
        if grep -E "$PATTERN" "$FILE" | grep -E -v "\s(0)?[0-6][04]0\s"; then
            crit "Logrotate permissions are not set to $PERMISSIONS"
        else
            ok "Logrotate permissions are well configured"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    does_pattern_exist_in_file "$FILE" "$PATTERN"
    if [ "$FNRET" != 0 ]; then
        warn "Logrotate permissions are not configured, fixing it"
        add_end_of_file "$FILE" "create $PERMISSIONS root utmp"
    else
        RESULT=$(grep -E "$PATTERN" "$FILE" | grep -E -v "\s(0)?[0-6][04]0\s")
        if [[ -n "$RESULT" ]]; then
            warn "Logrotate permissions are not set to $PERMISSIONS, fixing it"
            d_IFS=$IFS
            c_IFS=$'\n'
            IFS=$c_IFS
            for SOURCE in $RESULT; do
                replace_in_file "$FILE" "$SOURCE" "create $PERMISSIONS root utmp"
            done
            IFS=$d_IFS
        else
            ok "Logrotate permissions are well configured"
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
