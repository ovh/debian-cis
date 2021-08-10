#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 5.2.23 Ensure SSH MaxSessions is limited (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Limit SSH MaxSessions."

PACKAGE='openssh-server'
OPTIONS=''
FILE='/etc/ssh/sshd_config'

# This function will be called if the script status is on enabled / audit mode
audit() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        ok "$PACKAGE is not installed!"
    else
        ok "$PACKAGE is installed"
        for SSH_OPTION in $OPTIONS; do
            SSH_PARAM=$(echo "$SSH_OPTION" | cut -d= -f 1)
            SSH_VALUE=$(echo "$SSH_OPTION" | cut -d= -f 2)
            PATTERN="^${SSH_PARAM}[[:space:]]*$SSH_VALUE"
            does_pattern_exist_in_file_nocase $FILE "$PATTERN"
            if [ "$FNRET" = 0 ]; then
                ok "$PATTERN is present in $FILE"
            else
                does_pattern_exist_in_file_nocase "$FILE" "^${SSH_PARAM}"
                if [ "$FNRET" != 0 ]; then
                    crit "$PATTERN is not present in $FILE"
                else
                    VALUE=$($SUDO_CMD grep -i "^${SSH_PARAM}" "$FILE" | tr -s ' ' | cut -d' ' -f2)
                    if [ "$VALUE" -gt "$SSH_VALUE" ]; then
                        crit "$VALUE is higher than recommended $SSH_VALUE for $SSH_PARAM"
                    else
                        ok "$VALUE is lower than recommended $SSH_VALUE for $SSH_PARAM"
                    fi
                fi
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
    for SSH_OPTION in $OPTIONS; do
        SSH_PARAM=$(echo "$SSH_OPTION" | cut -d= -f 1)
        SSH_VALUE=$(echo "$SSH_OPTION" | cut -d= -f 2)
        PATTERN="^${SSH_PARAM}[[:space:]]*$SSH_VALUE"
        does_pattern_exist_in_file_nocase "$FILE" "$PATTERN"
        if [ "$FNRET" = 0 ]; then
            ok "$PATTERN is present in $FILE"
        else
            warn "$PATTERN is not present in $FILE, adding it"
            does_pattern_exist_in_file_nocase "$FILE" "^${SSH_PARAM}"
            if [ "$FNRET" != 0 ]; then
                add_end_of_file "$FILE" "$SSH_PARAM $SSH_VALUE"
            else
                VALUE=$(grep -i "^${SSH_PARAM}" "$FILE" | tr -s ' ' | cut -d' ' -f2)
                if [ "$VALUE" -gt "$SSH_VALUE" ]; then
                    warn "$VALUE is higher than recommended $SSH_VALUE for $SSH_PARAM, replacing it"
                    replace_in_file "$FILE" "^${SSH_PARAM}[[:space:]]*.*" "$SSH_PARAM $SSH_VALUE"
                else
                    ok "$VALUE is lower than recommended $SSH_VALUE for $SSH_PARAM"
                fi
            fi
            /etc/init.d/ssh reload
        fi
    done
}

# This function will check config parameters required
check_config() {
    :
}

# This function will check config parameters required
create_config() {
    cat <<EOF
status=audit
# Value of maxsessions
# Settles sshd maxsessions
OPTIONS='maxsessions=10'
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
