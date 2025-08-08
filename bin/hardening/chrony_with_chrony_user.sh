#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure chrony is running as user _chrony (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure chrony is running as user _chrony"
FILE='/etc/chrony/chrony.conf'
CHRONY_USER="_chrony"
USER_PATTERN="^user"

# This function will be called if the script status is on enabled / audit mode
audit() {
    CHRONY_USER_VALID=1

    if ! $SUDO_CMD pgrep -u "$CHRONY_USER" chronyd; then
        crit "chrony is not running as $CHRONY_USER"
    else
        ok "chrony is running as $CHRONY_USER"
        CHRONY_USER_VALID=0
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$CHRONY_USER_VALID" -ne 0 ]; then
        does_pattern_exist_in_file "$FILE" "$USER_PATTERN"
        if [ "$FNRET" -eq 0 ]; then
            sed -i '/'$USER_PATTERN'/d' "$FILE"
        fi

        add_end_of_file "$FILE" "user $CHRONY_USER"
        info "$FILE modified, please restart the service"
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
