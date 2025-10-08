#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure nologin is not listed in /etc/shells (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure nologin is not listed in /etc/shells (Automated)"

FILE='/etc/shells'
# By putting nologin in /etc/shells, any user that has nologin as its shell is considered a full, unrestricted user.
# This is not the expected behavior for nologin.

# This function will be called if the script status is on enabled / audit mode
audit() {
    ETC_SHELLS_VALID=0
    does_file_exist "$FILE"
    if [ "$FNRET" -eq 0 ]; then
        if $SUDO_CMD grep "nologin" "$FILE" >/dev/null 2>&1; then
            crit "'nologin' is present in $FILE"
            ETC_SHELLS_VALID=1
        fi
    fi

    if [ "$ETC_SHELLS_VALID" -eq 0 ]; then
        ok "'nologin' is not in $FILE"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$ETC_SHELLS_VALID" -ne 0 ]; then
        info "Removing 'nologin' from $FILE"
        sed -i '/nologin/d' "$FILE"
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
