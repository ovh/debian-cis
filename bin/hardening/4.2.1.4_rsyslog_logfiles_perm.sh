#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 4.2.1.4 Create and Set Permissions on rsyslog Log Files (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Create and set permissions on rsyslog logfiles."

# Note: this is not exacly the same check as the one described in CIS PDF

PACKAGE='rsyslog'
# shellcheck disable=2016
PATTERN='\$FileCreateMode[[:space:]]*0640'
FILES_TO_SEARCH='/etc/rsyslog.conf /etc/rsyslog.d'
PATTERN_TO_ADD='FileCreateMode 0640'
FILE='/etc/rsyslog.conf'

# This function will be called if the script status is on enabled / audit mode
audit() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        crit "$PACKAGE is not installed!"
    else
        SEARCH_RES=0
        for FILE_SEARCHED in $FILES_TO_SEARCH; do
            if [ "$SEARCH_RES" = 1 ]; then break; fi
            if test -d "$FILE_SEARCHED"; then
                debug "$FILE_SEARCHED is a directory"
                for file_in_dir in "$FILE_SEARCHED"/*; do
                    [[ -e "$file_in_dir" ]] || break # handle the case of no file in dir
                    does_pattern_exist_in_file "$file_in_dir" "^$PATTERN"
                    if [ "$FNRET" != 0 ]; then
                        debug "$PATTERN is not present in $file_in_dir"
                    else
                        ok "$PATTERN is present in $file_in_dir"
                        SEARCH_RES=1
                        break
                    fi
                done
            else
                does_pattern_exist_in_file "$FILE_SEARCHED" "^$PATTERN"
                if [ "$FNRET" != 0 ]; then
                    debug "$PATTERN is not present in $FILE_SEARCHED"
                else
                    ok "$PATTERN is present in $FILES_TO_SEARCH"
                    SEARCH_RES=1
                fi
            fi
        done
        if [ "$SEARCH_RES" = 0 ]; then
            crit "$PATTERN is not present in $FILES_TO_SEARCH"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" = 0 ]; then
        ok "$PACKAGE is installed"
    else
        crit "$PACKAGE is not installed, installing it"
        apt_install "$PACKAGE"
        info "Chcking $PACKAGE configuration"
    fi
    SEARCH_RES=0$
    for FILE_SEARCHED in $FILES_TO_SEARCH; do
        if [ "$SEARCH_RES" = 1 ]; then break; fi
        if test -d "$FILE_SEARCHED"; then
            debug "$FILE_SEARCHED is a directory"
            for file_in_dir in "$FILE_SEARCHED"/*; do
                [[ -e "$file_in_dir" ]] || break # handle the case of no file in dir
                does_pattern_exist_in_file "$file_in_dir" "^$PATTERN"
                if [ "$FNRET" != 0 ]; then
                    debug "$PATTERN is not present in $file_in_dir"
                else
                    ok "$PATTERN is present in $file_in_dir"
                    SEARCH_RES=1
                    break
                fi
            done
        else
            does_pattern_exist_in_file "$FILE_SEARCHED" "^$PATTERN"
            if [ "$FNRET" != 0 ]; then
                debug "$PATTERN is not present in $FILE_SEARCHED"
            else
                ok "$PATTERN is present in $FILES_TO_SEARCH"
                SEARCH_RES=1
            fi
        fi
    done
    if [ "$SEARCH_RES" = 0 ]; then
        warn "$PATTERN is not present in $FILES_TO_SEARCH"
        touch "$FILE"
        add_end_of_file "$FILE" "$PATTERN_TO_ADD"
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
