#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 5.4.4 Ensure default usershell timeout is 900 seconds or less
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
USER='root'
# shellcheck disable=2034
DESCRIPTION="Timeout 600 seconds on tty."

PATTERN='TMOUT='
VALUE='600'
FILES_TO_SEARCH='/etc/bash.bashrc /etc/profile.d /etc/profile'
FILE='/etc/profile.d/CIS_99.1_timeout.sh'

# This function will be called if the script status is on enabled / audit mode
audit() {
    SEARCH_RES=0
    for FILE_SEARCHED in $FILES_TO_SEARCH; do
        if [ "$SEARCH_RES" = 1 ]; then break; fi
        if test -d "$FILE_SEARCHED"; then
            debug "$FILE_SEARCHED is a directory"
            # shellcheck disable=2044
            for file_in_dir in $(find "$FILE_SEARCHED" -type f); do
                does_pattern_exist_in_file "$file_in_dir" "$PATTERN"
                if [ "$FNRET" != 0 ]; then
                    debug "$PATTERN is not present in $file_in_dir"
                else
                    ok "$PATTERN is present in $file_in_dir"
                    SEARCH_RES=1
                    break
                fi
            done
        else
            does_pattern_exist_in_file "$FILE_SEARCHED" "$PATTERN"
            if [ "$FNRET" != 0 ]; then
                debug "$PATTERN is not present in $FILE_SEARCHED"
            else
                ok "$PATTERN is present in $FILE_SEARCHED"
                SEARCH_RES=1
            fi
        fi
    done
    if [ "$SEARCH_RES" = 0 ]; then
        crit "$PATTERN is not present in $FILES_TO_SEARCH"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    SEARCH_RES=0
    for FILE_SEARCHED in $FILES_TO_SEARCH; do
        if [ "$SEARCH_RES" = 1 ]; then break; fi
        if test -d "$FILE_SEARCHED"; then
            debug "$FILE_SEARCHED is a directory"
            # shellcheck disable=2044
            for file_in_dir in $(find "$FILE_SEARCHED" -type f); do
                does_pattern_exist_in_file "$file_in_dir" "$PATTERN"
                if [ "$FNRET" != 0 ]; then
                    debug "$PATTERN is not present in $file_in_dir"
                else
                    ok "$PATTERN is present in $file_in_dir"
                    SEARCH_RES=1
                    break
                fi
            done
        else
            does_pattern_exist_in_file "$FILE_SEARCHED" "$PATTERN"
            if [ "$FNRET" != 0 ]; then
                debug "$PATTERN is not present in $FILE_SEARCHED"
            else
                ok "$PATTERN is present in $FILE_SEARCHED"
                SEARCH_RES=1
            fi
        fi
    done
    if [ "$SEARCH_RES" = 0 ]; then
        warn "$PATTERN is not present in $FILES_TO_SEARCH"
        touch "$FILE"
        chmod 644 "$FILE"
        add_end_of_file "$FILE" "readonly $PATTERN$VALUE"
        add_end_of_file "$FILE" "export TMOUT"
    else
        ok "$PATTERN is present in $FILES_TO_SEARCH"
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
