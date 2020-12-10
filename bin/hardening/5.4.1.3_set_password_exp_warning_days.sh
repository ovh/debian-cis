#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 5.4.1.3 Ensure password expiration warning days is 7 or more (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Set password expiration warning days."

PACKAGE='login'
OPTIONS=''
FILE='/etc/login.defs'

# This function will be called if the script status is on enabled / audit mode
audit() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        crit "$PACKAGE is not installed!"
    else
        ok "$PACKAGE is installed"
        for SHADOW_OPTION in $OPTIONS; do
            SHADOW_PARAM=$(echo "$SHADOW_OPTION" | cut -d= -f 1)
            SHADOW_VALUE=$(echo "$SHADOW_OPTION" | cut -d= -f 2)
            PATTERN="^${SHADOW_PARAM}[[:space:]]*$SHADOW_VALUE"
            does_pattern_exist_in_file "$FILE" "$PATTERN"
            if [ "$FNRET" = 0 ]; then
                ok "$PATTERN is present in $FILE"
            else
                crit "$PATTERN is not present in $FILE"
            fi
        done
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
    for SHADOW_OPTION in $OPTIONS; do
        SHADOW_PARAM=$(echo "$SHADOW_OPTION" | cut -d= -f 1)
        SHADOW_VALUE=$(echo "$SHADOW_OPTION" | cut -d= -f 2)
        PATTERN="^${SHADOW_PARAM}[[:space:]]*$SHADOW_VALUE"
        does_pattern_exist_in_file "$FILE" "$PATTERN"
        if [ "$FNRET" = 0 ]; then
            ok "$PATTERN is present in $FILE"
        else
            warn "$PATTERN is not present in $FILE, adding it"
            does_pattern_exist_in_file "$FILE" "^${SHADOW_PARAM}"
            if [ "$FNRET" != 0 ]; then
                add_end_of_file "$FILE" "$SHADOW_PARAM $SHADOW_VALUE"
            else
                info "Parameter $SHADOW_PARAM is present but with the wrong value -- Fixing"
                replace_in_file "$FILE" "^${SHADOW_PARAM}[[:space:]]*.*" "$SHADOW_PARAM $SHADOW_VALUE"
            fi
        fi
    done
}

# This function will check config parameters required
check_config() {
    :
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
# shellcheck disable=2034
status=audit
# Put here your protocol for shadow
OPTIONS='PASS_WARN_AGE=7'
EOF
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
