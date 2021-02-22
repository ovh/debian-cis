#!/bin/bash

# run-shellcheck
#
# Legacy CIS Debian Hardening
#

#
# 99.3.3.4 Ensure permissions on /etc/hosts.allow are configured (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Check 644 permissions and root:root ownership on /hosts.allow ."

FILE='/etc/hosts.allow'
PERMISSIONS='644'
USER='root'
GROUP='root'

# This function will be called if the script status is on enabled / audit mode
audit() {
    does_file_exist "$FILE"
    if [ "$FNRET" != 0 ]; then
        crit "$FILE does not exist"
    else
        ok "$FILE exist"
        has_file_correct_permissions "$FILE" "$PERMISSIONS"
        if [ "$FNRET" = 0 ]; then
            ok "$FILE has correct permissions"
        else
            crit "$FILE permissions were not set to $PERMISSIONS"
        fi
        has_file_correct_ownership "$FILE" "$USER" "$GROUP"
        if [ "$FNRET" = 0 ]; then
            ok "$FILE has correct ownership"
        else
            crit "$FILE ownership was not set to $USER:$GROUP"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    does_file_exist "$FILE"
    if [ "$FNRET" != 0 ]; then
        warn "$FILE does not exist"
        touch "$FILE"
        warn "You may want to fill it with allowed networks"
    else
        ok "$FILE exist"
    fi
    has_file_correct_permissions "$FILE" "$PERMISSIONS"
    if [ "$FNRET" = 0 ]; then
        ok "$FILE has correct permissions"
    else
        info "fixing $FILE permissions to $PERMISSIONS"
        chmod 0"$PERMISSIONS" "$FILE"
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
