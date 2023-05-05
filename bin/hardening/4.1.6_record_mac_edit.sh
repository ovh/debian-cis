#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 4.1.6 Ensure that events that modify the system's Mandatory Access Controls are collected (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=4
# shellcheck disable=2034
DESCRIPTION="Record events that modify the system's mandatory access controls (MAC)."

AUDIT_PARAMS='-w /etc/selinux/ -p wa -k MAC-policy'
FILES_TO_SEARCH='/etc/audit/audit.rules /etc/audit/rules.d/audit.rules'
FILE='/etc/audit/rules.d/audit.rules'

# This function will be called if the script status is on enabled / audit mode
audit() {
    # define custom IFS and save default one
    d_IFS=$IFS
    c_IFS=$'\n'
    IFS=$c_IFS
    for AUDIT_VALUE in $AUDIT_PARAMS; do
        debug "$AUDIT_VALUE should be in file $FILES_TO_SEARCH"
        IFS=$d_IFS
        SEARCH_RES=0
        for FILE_SEARCHED in $FILES_TO_SEARCH; do
            does_pattern_exist_in_file "$FILE_SEARCHED" "$AUDIT_VALUE"
            IFS=$c_IFS
            if [ "$FNRET" != 0 ]; then
                debug "$AUDIT_VALUE is not in file $FILE_SEARCHED"
            else
                ok "$AUDIT_VALUE is present in $FILE_SEARCHED"
                SEARCH_RES=1
            fi
        done
        if [ "$SEARCH_RES" = 0 ]; then
            crit "$AUDIT_VALUE is not present in $FILES_TO_SEARCH"
        fi
    done
    IFS=$d_IFS
}

# This function will be called if the script status is on enabled mode
apply() {
    # define custom IFS and save default one
    d_IFS=$IFS
    c_IFS=$'\n'
    IFS=$c_IFS
    for AUDIT_VALUE in $AUDIT_PARAMS; do
        debug "$AUDIT_VALUE should be in file $FILES_TO_SEARCH"
        IFS=$d_IFS
        SEARCH_RES=0
        for FILE_SEARCHED in $FILES_TO_SEARCH; do
            does_pattern_exist_in_file "$FILE_SEARCHED" "$AUDIT_VALUE"
            IFS=$c_IFS
            if [ "$FNRET" != 0 ]; then
                debug "$AUDIT_VALUE is not in file $FILE_SEARCHED"
            else
                ok "$AUDIT_VALUE is present in $FILE_SEARCHED"
                SEARCH_RES=1
            fi
        done
        if [ "$SEARCH_RES" = 0 ]; then
            warn "$AUDIT_VALUE is not present in $FILES_TO_SEARCH, adding it to $FILE"
            add_end_of_file "$FILE" "$AUDIT_VALUE"
            eval "$(pkill -HUP -P 1 auditd)"
        fi
    done
    IFS=$d_IFS
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
