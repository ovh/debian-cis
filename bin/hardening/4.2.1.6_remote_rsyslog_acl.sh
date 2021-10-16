#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 4.2.1.6 Ensure remote rsyslog messages are only accepted on designated log hosts. (Not Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Configure rsyslog to accept remote syslog messages only on designated log hosts."

# Note: this is not exacly the same check as the one described in CIS PDF

PACKAGE='rsyslog'
REMOTE_HOST=""
# shellcheck disable=2016
PATTERN='(\$ModLoad imtcp|\$InputTCPServerRun)'
FILES_TO_SEARCH='/etc/rsyslog.conf /etc/rsyslog.d'

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
        if [[ "$REMOTE_HOST" ]]; then
            info "This is the remote host, checking that it only accepts logs from specified zone"
            if [ "$SEARCH_RES" = 1 ]; then
                ok "$PATTERN is present in $FILES_TO_SEARCH"
            else
                crit "$PATTERN is not present in $FILES_TO_SEARCH"
            fi
        else
            info "This is the not the remote host checking that it doesn't accept remote logs"
            if [ "$SEARCH_RES" = 1 ]; then
                crit "$PATTERN is present in $FILES_TO_SEARCH"
            else
                ok "$PATTERN is not present in $FILES_TO_SEARCH"
            fi
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
    if [[ "$REMOTE_HOST" ]]; then
        info "This is the remote host, checking that it only accepts logs from specified zone"
        if [ "$SEARCH_RES" = 1 ]; then
            ok "$PATTERN is present in $FILES_TO_SEARCH"
        else
            crit "$PATTERN is not present in $FILES_TO_SEARCH, setup the machine to receive the logs"
        fi
    else
        info "This is the not the remote host checking that it doesn't accept remote logs"
        if [ "$SEARCH_RES" = 1 ]; then
            warn "$PATTERN is present in $FILES_TO_SEARCH, "
        else
            ok "$PATTERN is not present in $FILES_TO_SEARCH, setup the machine to deny remote logs"
        fi
    fi
}

# This function will check config parameters required
check_config() {
    :
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit
# Set REMOTE_HOST to "true" if it's the remote host
REMOTE_HOST=""
EOF
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
