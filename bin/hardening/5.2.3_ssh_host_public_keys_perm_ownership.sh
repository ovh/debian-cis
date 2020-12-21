#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 5.2.3 Ensure permissions on SSH public host key files are configured (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Checking permissions and ownership to root 644 for ssh public keys. "

DIR='/etc/ssh'
PERMISSIONS='644'
PERMISSIONSOK='644 640 600'
USER='root'
GROUP='root'

# This function will be called if the script status is on enabled / audit mode
audit() {
    ERRORS=0
    for FILE in $($SUDO_CMD find $DIR -xdev -type f -name 'ssh_host_*_key.pub'); do
        has_file_one_of_permissions "$FILE" "$PERMISSIONSOK"
        if [ "$FNRET" = 0 ]; then
            ok "$FILE permissions were set to $PERMISSIONS"
        else
            ERRORS=$((ERRORS + 1))
            crit "$FILE permissions were not set to $PERMISSIONS"
        fi

    done

    if [ "$ERRORS" = 0 ]; then
        ok "SSH public keys in $DIR have correct permissions"
    fi

    ERRORS=0
    for FILE in $($SUDO_CMD find $DIR -xdev -type f -name 'ssh_host_*_key.pub'); do
        has_file_correct_ownership "$FILE" "$USER" "$GROUP"
        if [ "$FNRET" = 0 ]; then
            ok "$FILE ownership was set to $USER:$GROUP"

        else
            ERRORS=$((ERRORS + 1))
            crit "$FILE ownership was not set to $USER:$GROUP"
        fi
    done

    if [ "$ERRORS" = 0 ]; then
        ok "SSH public keys in $DIR have correct ownership"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    for FILE in $($SUDO_CMD find $DIR -xdev -type f -name 'ssh_host_*_key.pub'); do
        has_file_one_of_permissions "$FILE" "$PERMISSIONSOK"
        if [ "$FNRET" = 0 ]; then
            ok "$FILE permissions were set to $PERMISSIONS"
        else
            warn "fixing $DIR SSH public keys permissions to $PERMISSIONS"
            chmod 0"$PERMISSIONS" "$FILE"
        fi
    done

    for FILE in $($SUDO_CMD find $DIR -xdev -type f -name 'ssh_host_*_key.pub'); do
        has_file_correct_ownership "$FILE" "$USER" "$GROUP"
        if [ "$FNRET" = 0 ]; then
            ok "$FILE ownership was set to $USER:$GROUP"
        else
            warn "fixing $DIR SSH public keys ownership to $USER:$GROUP"
            chown "$USER":"$GROUP" "$FILE"
        fi
    done

}

# This function will check config parameters required
check_config() {
    does_user_exist "$USER"
    if [ "$FNRET" != 0 ]; then
        crit "$USER does not exist"
        exit 128
    fi
    does_group_exist "$GROUP"
    if [ "$FNRET" != 0 ]; then
        crit "$GROUP does not exist"
        exit 128
    fi
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
