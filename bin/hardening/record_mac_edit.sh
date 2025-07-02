#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure that events that modify the system's Mandatory Access Controls are collected (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=4
# shellcheck disable=2034
DESCRIPTION="Record events that modify the system's mandatory access controls (MAC)."

AUDIT_PARAMS=("-w /etc/apparmor/ -p wa -k MAC-policy" "-w /etc/apparmor.d/ -p wa -k MAC-policy")
AUDIT_FILE='/etc/audit/audit.rules'
ADDITIONAL_PATH="/etc/audit/rules.d"
FILE_TO_WRITE='/etc/audit/rules.d/audit.rules'

# This function will be called if the script status is on enabled / audit mode
audit() {
    MISSING_PARAMS=()
    index=0
    # use find here in order to simplify test usage with sudo using secaudit user
    FILES_TO_SEARCH="$(sudo_wrapper find $ADDITIONAL_PATH -name '*.rules' | paste -s) $AUDIT_FILE"
    for i in "${!AUDIT_PARAMS[@]}"; do
        debug "${AUDIT_PARAMS[i]} should be in file $FILES_TO_SEARCH"
        SEARCH_RES=0
        for FILE_SEARCHED in $FILES_TO_SEARCH; do
            does_pattern_exist_in_file "$FILE_SEARCHED" "${AUDIT_PARAMS[i]}"
            if [ "$FNRET" != 0 ]; then
                debug "${AUDIT_PARAMS[i]} is not in file $FILE_SEARCHED"
            else
                ok "${AUDIT_PARAMS[i]} is present in $FILE_SEARCHED"
                SEARCH_RES=1
            fi
        done
        if [ "$SEARCH_RES" = 0 ]; then
            crit "${AUDIT_PARAMS[i]} is not present in $FILES_TO_SEARCH"
            MISSING_PARAMS[i]="${AUDIT_PARAMS[i]}"
            index=$((index + 1))
        fi
    done
}

# This function will be called if the script status is on enabled mode
apply() {
    audit
    changes=0
    for i in "${!MISSING_PARAMS[@]}"; do
        info "${MISSING_PARAMS[i]} is not present in $FILES_TO_SEARCH, adding it"
        add_end_of_file "$FILE_TO_WRITE" "${MISSING_PARAMS[i]}"
        changes=1
    done

    [ "$changes" -eq 0 ] || eval "$(pkill -HUP -P 1 auditd)"
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
if [ -z "$CIS_LIB_DIR" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_LIB_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r "${CIS_LIB_DIR}"/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "${CIS_LIB_DIR}"/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_LIB_DIR in /etc/default/cis-hardening"
    exit 128
fi
