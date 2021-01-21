#!/bin/bash

# run-shellcheck
#
# Legacy CIS Debian Hardening
#

#
# 99.5.2.6 Restrict which user's variables are accepted by ssh daemon
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Restrict which user's variables are accepted by ssh daemon"

PACKAGE='openssh-server'
PATTERN='^\s*AcceptEnv\s+LANG LC_\*'
FILE='/etc/ssh/sshd_config'

# This function will be called if the script status is on enabled / audit mode
audit() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        ok "$PACKAGE is not installed!"
    else
        ok "$PACKAGE is installed"
        does_pattern_exist_in_file_nocase "$FILE" "$PATTERN"
        if [ "$FNRET" = 0 ]; then
            ok "$PATTERN is present in $FILE"
        else
            crit "$PATTERN is not present in $FILE"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" = 0 ]; then
        ok "$PACKAGE is installed"
    else
        crit "$PACKAGE is absent, installing it"
        apt_install "$PACKAGE"
    fi
    does_pattern_exist_in_file_nocase "$FILE" "$PATTERN"
    if [ "$FNRET" = 0 ]; then
        ok "$PATTERN is present in $FILE"
    else
        warn "$PATTERN is not present in $FILE, adding it"
        does_pattern_exist_in_file_nocase "$FILE" "^$PATTERN"
        # shellcheck disable=SC2001
        PATTERN=$(sed 's/\^//' <<<"$PATTERN" | sed -r 's/\\s\*//' | sed -r 's/\\s\+/ /g' | sed 's/\\//g')
        if [ "$FNRET" != 0 ]; then
            add_end_of_file "$FILE" "$PATTERN"
        else
            info "Parameter $SSH_PARAM is present but with the wrong value -- Fixing"
            replace_in_file "$FILE" "^${SSH_PARAM}[[:space:]]*.*" "$PATTERN"
        fi
        /etc/init.d/ssh reload >/dev/null 2>&1
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
