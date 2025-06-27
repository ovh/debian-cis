#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure password maximum sequential characters is configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure password maximum sequential characters is configured"

OPTIONS=''
FILE_QUALITY='/etc/security/pwquality.conf'

# This function will be called if the script status is on enabled / audit mode
audit() {
    for PW_OPT in $OPTIONS; do
        PW_PARAM=$(echo "$PW_OPT" | cut -d= -f1)
        PW_VALUE=$(echo "$PW_OPT" | cut -d= -f2)
        # note : dont backslash regex characters, as 'does_pattern_exist_in_file' use "grep -E" which don't need it
        PATTERN="^${PW_PARAM}[[:space:]]?+=[[:space:]]?+$PW_VALUE"
        does_pattern_exist_in_file "$FILE_QUALITY" "$PATTERN"

        if [ "$FNRET" = 0 ]; then
            ok "$PATTERN is present in $FILE_QUALITY"
        else
            crit "$PATTERN is not present in $FILE_QUALITY"
        fi
    done
}

# This function will be called if the script status is on enabled mode
apply() {
    for PW_OPT in $OPTIONS; do
        PW_PARAM=$(echo "$PW_OPT" | cut -d= -f1)
        PW_VALUE=$(echo "$PW_OPT" | cut -d= -f2)
        PATTERN="^${PW_PARAM}[[:space:]]?+=[[:space:]]?+$PW_VALUE"
        does_pattern_exist_in_file "$FILE_QUALITY" "$PATTERN"
        if [ "$FNRET" = 0 ]; then
            ok "$PATTERN is present in $FILE_QUALITY"
        else
            warn "$PATTERN is not present in $FILE_QUALITY, adding it"
            does_pattern_exist_in_file "$FILE_QUALITY" "^${PW_PARAM}"
            if [ "$FNRET" != 0 ]; then
                add_end_of_file "$FILE_QUALITY" "$PW_PARAM = $PW_VALUE"
            else
                info "Parameter $PW_PARAM is present but with the wrong value -- Fixing"
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
OPTIONS="maxsequence=3"
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
if [ -z "$CIS_LIB_DIR" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_LIB_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r "${CIS_LIB_DIR}"/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "${CIS_LIB_DIR}"/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_LIB_DIR in /etc/default/cis-hardening"
    exit 128
fi
