#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 4.1.2.3 Ensure audit logs are not automatically deleted (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=4
# shellcheck disable=2034
DESCRIPTION="Keep all auditing information."

FILE='/etc/audit/auditd.conf'
OPTIONS='max_log_file_action=keep_logs'

# This function will be called if the script status is on enabled / audit mode
audit() {
    does_file_exist "$FILE"
    if [ "$FNRET" != 0 ]; then
        crit "$FILE does not exist"
    else
        ok "$FILE exists, checking configuration"
        for AUDIT_OPTION in $OPTIONS; do
            AUDIT_PARAM=$(echo "$AUDIT_OPTION" | cut -d= -f 1)
            AUDIT_VALUE=$(echo "$AUDIT_OPTION" | cut -d= -f 2)
            PATTERN="^${AUDIT_PARAM}[[:space:]]*=[[:space:]]*$AUDIT_VALUE"
            debug "$AUDIT_PARAM should be set to $AUDIT_VALUE"
            does_pattern_exist_in_file "$FILE" "$PATTERN"
            if [ "$FNRET" != 0 ]; then
                crit "$PATTERN is not present in $FILE"
            else
                ok "$PATTERN is present in $FILE"
            fi
        done
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    does_file_exist "$FILE"
    if [ "$FNRET" != 0 ]; then
        warn "$FILE does not exist, creating it"
        touch $FILE
    else
        ok "$FILE exists"
    fi
    for AUDIT_OPTION in $OPTIONS; do
        AUDIT_PARAM=$(echo "$AUDIT_OPTION" | cut -d= -f 1)
        AUDIT_VALUE=$(echo "$AUDIT_OPTION" | cut -d= -f 2)
        debug "$AUDIT_PARAM should be set to $AUDIT_VALUE"
        PATTERN="^${AUDIT_PARAM}[[:space:]]*=[[:space:]]*$AUDIT_VALUE"
        does_pattern_exist_in_file $FILE "$PATTERN"
        if [ "$FNRET" != 0 ]; then
            warn "$PATTERN is not present in $FILE, adding it"
            does_pattern_exist_in_file "$FILE" "^$AUDIT_PARAM"
            if [ "$FNRET" != 0 ]; then
                info "Parameter $AUDIT_PARAM seems absent from $FILE, adding at the end"
                add_end_of_file "$FILE" "$AUDIT_PARAM = $AUDIT_VALUE"
            else
                info "Parameter $AUDIT_PARAM is present but with the wrong value -- Fixing"
                replace_in_file "$FILE" "^${AUDIT_PARAM}[[:space:]]*=.*" "$AUDIT_PARAM = $AUDIT_VALUE"
            fi
        else
            ok "$PATTERN is present in $FILE"
        fi
    done
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
