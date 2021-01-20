#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 4.2.2.1 Ensure journald is configured to send logs to syslog-ng (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Configure journald to send logs to syslog-ng."

FILE='/etc/systemd/journald.conf'
OPTIONS='ForwardToSyslog=no'

# This function will be called if the script status is on enabled / audit mode
audit() {
    does_file_exist "$FILE"
    if [ "$FNRET" != 0 ]; then
        crit "$FILE does not exist"
    else
        ok "$FILE exists, checking configuration"
        for JOURNALD_OPTION in $OPTIONS; do
            JOURNALD_PARAM=$(echo "$JOURNALD_OPTION" | cut -d= -f 1)
            JOURNALD_VALUE=$(echo "$JOURNALD_OPTION" | cut -d= -f 2)
            PATTERN="^$JOURNALD_PARAM=$JOURNALD_VALUE"
            debug "$JOURNALD_PARAM should be set to $JOURNALD_VALUE"
            does_pattern_exist_in_file "$FILE" "$PATTERN"
            if [ "$FNRET" != 0 ]; then
                ok "$PATTERN is not present in $FILE"
            else
                crit "$PATTERN is present in $FILE"
            fi
        done
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    does_file_exist "$FILE"
    if [ "$FNRET" != 0 ]; then
        warn "$FILE does not exist, creating it"
        touch "$FILE"
    else
        ok "$FILE exists"
    fi
    for JOURNALD_OPTION in $OPTIONS; do
        JOURNALD_PARAM=$(echo "$JOURNALD_OPTION" | cut -d= -f 1)
        JOURNALD_VALUE=$(echo "$JOURNALD_OPTION" | cut -d= -f 2)
        debug "$JOURNALD_PARAM should be set to $JOURNALD_VALUE"
        PATTERN="^$JOURNALD_PARAM=$JOURNALD_VALUE"
        does_pattern_exist_in_file "$FILE" "$PATTERN"
        if [ "$FNRET" = 0 ]; then
            warn "$PATTERN is present in $FILE, deleting it"
            does_pattern_exist_in_file "$FILE" "^$JOURNALD_PARAM"
            if [ "$FNRET" != 0 ]; then
                info "Parameter $JOURNALD_PARAM seems absent from $FILE, adding at the end"
                add_end_of_file "$FILE" "$JOURNALD_PARAM=yes"
            else
                info "Parameter $JOURNALD_PARAM is present but with the wrong value -- Fixing"
                replace_in_file "$FILE" "^$JOURNALD_PARAM=.*" "$JOURNALD_PARAM=yes"
            fi
        else
            ok "$PATTERN is not present in $FILE"
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
