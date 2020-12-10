#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 5.3.1 Ensure password creation requirements are configured (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Set password creation requirement parameters using pam.cracklib."

PACKAGE='libpam-pwquality'

PATTERN_COMMON='pam_pwquality.so'
FILE_COMMON='/etc/pam.d/common-password'

OPTIONS=''
FILE_QUALITY='/etc/security/pwquality.conf'

# This function will be called if the script status is on enabled / audit mode
audit() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        crit "$PACKAGE is not installed!"
    else
        ok "$PACKAGE is installed"
        does_pattern_exist_in_file "$FILE_COMMON" "$PATTERN_COMMON"
        if [ "$FNRET" = 0 ]; then
            ok "$PATTERN_COMMON is present in $FILE_COMMON"
        else
            crit "$PATTERN_COMMON is not present in $FILE_COMMON"
        fi
        for PW_OPT in $OPTIONS; do
            PW_PARAM=$(echo "$PW_OPT" | cut -d= -f1)
            PW_VALUE=$(echo "$PW_OPT" | cut -d= -f2)
            PATTERN="^${PW_PARAM}[[:space:]]+=[[:space:]]+$PW_VALUE"
            does_pattern_exist_in_file "$FILE_QUALITY" "$PATTERN"

            if [ "$FNRET" = 0 ]; then
                ok "$PATTERN is present in $FILE_QUALITY"
            else
                crit "$PATTERN is not present in $FILE_QUALITY"
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
    does_pattern_exist_in_file $FILE_COMMON $PATTERN_COMMON
    if [ "$FNRET" = 0 ]; then
        ok "$PATTERN_COMMON is present in $FILE_COMMON"
    else
        warn "$PATTERN_COMMON is not present in $FILE_COMMON"
        add_line_file_before_pattern "$FILE_COMMON" "password requisite pam_pwquality.so retry=3" "# pam-auth-update(8) for details."
    fi

    for PW_OPT in $OPTIONS; do
        PW_PARAM=$(echo "$PW_OPT" | cut -d= -f1)
        PW_VALUE=$(echo "$PW_OPT" | cut -d= -f2)
        PATTERN="^${PW_PARAM}[[:space:]]+=[[:space:]]+$PW_VALUE"
        does_pattern_exist_in_file "$FILE_QUALITY" "$PATTERN"
        if [ "$FNRET" = 0 ]; then
            ok "$PATTERN is present in $FILE_QUALITY"
        else
            warn "$PATTERN is not present in $FILE_QUALITY, adding it"
            does_pattern_exist_in_file "$FILE_QUALITY" "^${PW_PARAM}"
            if [ "$FNRET" != 0 ]; then
                add_end_of_file "$FILE_QUALITY" "$PW_PARAM = $PW_VALUE"
            else
                info "Parameter $SSH_PARAM is present but with the wrong value -- Fixing"
                replace_in_file "$FILE_QUALITY" "^${PW_PARAM}*.*" "$PW_PARAM = $PW_VALUE"
            fi
        fi
    done
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit
# Put your custom configuration here
OPTIONS="minlen=14 dcredit=-1 ucredit=-1 ocredit=-1 lcredit=-1"
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
