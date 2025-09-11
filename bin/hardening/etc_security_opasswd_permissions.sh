#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure permissions on /etc/security/opasswd are configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="verify /etc/security/opasswd and /etc/security/opasswd.old are mode 600 or more restrictive, Uid is 0/root and Gid is 0/root"

FILES='/etc/security/opasswd /etc/security/opasswd.old'

# This function will be called if the script status is on enabled / audit mode
audit() {
    # we treat both files as one for simplicity
    PERMS_VALID=0
    UID_VALID=0
    GID_VALID=0

    VALID_FILES=""
    for file in $FILES; do
        does_file_exist "$file"
        if [ "$FNRET" -eq 0 ]; then
            VALID_FILES="$VALID_FILES $file"
        fi
    done

    for file in $VALID_FILES; do

        file_stats=$(stat -Lc '%a %u %g' "$file")

        if ! grep "[0-6]00" <<<"$(awk '{print $1}' <<<"$file_stats")" >/dev/null; then
            crit "$file 's perms are not 600 or less"
            PERMS_VALID=1
        fi

        if [ "$(awk '{print $2}' <<<"$file_stats")" -ne 0 ]; then
            crit "$file owner's uid is not 0"
            UID_VALID=1
        fi

        if [ "$(awk '{print $3}' <<<"$file_stats")" -ne 0 ]; then
            crit "$file group's gid is not 0"
            GID_VALID=1
        fi

    done

}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$PERMS_VALID" -eq 1 ]; then
        for file in $VALID_FILES; do
            info "changing permission to 600 on $file"
            chmod 600 "$file"
        done
    fi

    if [ "$UID_VALID" -eq 1 ]; then
        for file in $VALID_FILES; do
            info "changing owner to 0 on $file"
            chown 0 "$file"
        done
    fi

    if [ "$GID_VALID" -eq 1 ]; then
        for file in $VALID_FILES; do
            info "changing group to 0 on $file"
            chgrp 0 "$file"
        done
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
