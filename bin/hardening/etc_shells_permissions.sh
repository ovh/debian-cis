#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure permissions on /etc/shells are configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="verify /etc/shells is mode 644 or more restrictive, Uid is 0/root and Gid is 0/root"

FILE='/etc/shells'

# This function will be called if the script status is on enabled / audit mode
audit() {
    PERMS_VALID=0
    UID_VALID=0
    GID_VALID=0

    does_file_exist "$FILE"
    if [ "$FNRET" -eq 0 ]; then
        file_stats=$(stat -Lc '%a %u %g' "$FILE")

        if ! grep "[0-6][0-4][0-4]" <<<"$(awk '{print $1}' <<<"$file_stats")" >/dev/null; then
            crit "$FILE 's perms are not 644 or less"
            PERMS_VALID=1
        fi

        if [ "$(awk '{print $2}' <<<"$file_stats")" -ne 0 ]; then
            crit "$FILE owner's uid is not 0"
            UID_VALID=1
        fi

        if [ "$(awk '{print $3}' <<<"$file_stats")" -ne 0 ]; then
            crit "$FILE group's gid is not 0"
            GID_VALID=1
        fi

    else
        info "$FILE is missing"
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$PERMS_VALID" -eq 1 ]; then
        info "changing permission to 644 on $FILE"
        chmod 644 "$FILE"
    fi

    if [ "$UID_VALID" -eq 1 ]; then
        info "changing owner to 0 on $FILE"
        chown 0 "$FILE"
    fi

    if [ "$GID_VALID" -eq 1 ]; then
        info "changing group to 0 on $FILE"
        chgrp 0 "$FILE"
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
