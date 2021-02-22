#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 4.2.1.5 Ensure syslog-ng is configured to send logs to a remote log host (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Configure syslog-ng to send logs to a remote log host."

PACKAGE='syslog-ng'

PATTERN='destination[[:alnum:][:space:]*{]+(tcp|udp)[[:space:]]*\(\"[[:alnum:].]+\".'

# This function will be called if the script status is on enabled / audit mode
audit() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        crit "$PACKAGE is not installed!"
    else
        FOUND=0
        FILES="$SYSLOG_BASEDIR/syslog-ng.conf $($SUDO_CMD find -L "$SYSLOG_BASEDIR"/conf.d/ -type f)"
        for FILE in $FILES; do
            does_pattern_exist_in_file_multiline "$FILE" "$PATTERN"
            if [ "$FNRET" = 0 ]; then
                FOUND=1
            fi
        done

        if [ "$FOUND" = 1 ]; then
            ok "$PATTERN is present in $FILES"
        else
            crit "$PATTERN is not present in $FILES"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        crit "$PACKAGE is not installed!"
    else
        FOUND=0
        FILES="$SYSLOG_BASEDIR/syslog-ng.conf $(find -L "$SYSLOG_BASEDIR"/conf.d/ -type f)"
        for FILE in $FILES; do
            does_pattern_exist_in_file_multiline "$FILE" "$PATTERN"
            if [ "$FNRET" = 0 ]; then
                FOUND=1
            fi
        done
        if [ "$FOUND" = 1 ]; then
            ok "$PATTERN is present in $FILES"
        else
            crit "$PATTERN is not present in $FILES, please set a remote host to send your logs"
        fi
    fi
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit
SYSLOG_BASEDIR='/etc/syslog-ng'
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
