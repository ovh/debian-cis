#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

set -e
set -u

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Ensure permissions on /boot/grub/grub.cfg are 0600 or more restrictive, and owned by root:root"

# Global variables with unique prefix
GRUB_CFG_PERM_FILE="/boot/grub/grub.cfg"
GRUB_CFG_PERM_USER="root"
GRUB_CFG_PERM_GROUP="root"
GRUB_CFG_PERM_MODE="600"
# Global variables to store audit state
GRUB_CFG_PERM_FILE_EXISTS=1
GRUB_CFG_PERM_OWNERSHIP_OK=1
GRUB_CFG_PERM_PERMISSIONS_OK=1

audit() {
    does_file_exist "$GRUB_CFG_PERM_FILE"
    GRUB_CFG_PERM_FILE_EXISTS=$FNRET
    if [ "$GRUB_CFG_PERM_FILE_EXISTS" -ne 0 ]; then
        ok "$GRUB_CFG_PERM_FILE not found (GRUB not installed)"
        return
    fi

    has_file_correct_ownership "$GRUB_CFG_PERM_FILE" "$GRUB_CFG_PERM_USER" "$GRUB_CFG_PERM_GROUP"
    GRUB_CFG_PERM_OWNERSHIP_OK=$FNRET
    if [ "$GRUB_CFG_PERM_OWNERSHIP_OK" -ne 0 ]; then
        crit "$GRUB_CFG_PERM_FILE ownership is incorrect (expected $GRUB_CFG_PERM_USER:$GRUB_CFG_PERM_GROUP)"
        return
    fi

    has_file_correct_permissions "$GRUB_CFG_PERM_FILE" "$GRUB_CFG_PERM_MODE"
    GRUB_CFG_PERM_PERMISSIONS_OK=$FNRET
    if [ "$GRUB_CFG_PERM_PERMISSIONS_OK" -ne 0 ]; then
        crit "$GRUB_CFG_PERM_FILE permissions are incorrect (expected $GRUB_CFG_PERM_MODE or more restrictive)"
        return
    fi

    ok "$GRUB_CFG_PERM_FILE has correct ownership and permissions"
}

apply() {
    if [ "$GRUB_CFG_PERM_FILE_EXISTS" -ne 0 ]; then
        ok "$GRUB_CFG_PERM_FILE not found (nothing to apply)"
        return
    fi

    if [ "$GRUB_CFG_PERM_OWNERSHIP_OK" -ne 0 ]; then
        info "Setting ownership of $GRUB_CFG_PERM_FILE to $GRUB_CFG_PERM_USER:$GRUB_CFG_PERM_GROUP"
        chown "$GRUB_CFG_PERM_USER:$GRUB_CFG_PERM_GROUP" "$GRUB_CFG_PERM_FILE"
    fi

    if [ "$GRUB_CFG_PERM_PERMISSIONS_OK" -ne 0 ]; then
        info "Setting permissions of $GRUB_CFG_PERM_FILE to $GRUB_CFG_PERM_MODE"
        chmod "$GRUB_CFG_PERM_MODE" "$GRUB_CFG_PERM_FILE"
    fi

    ok "$GRUB_CFG_PERM_FILE ownership and permissions are now correct"
}

check_config() {
    :
}

# Source Root Dir Parameter
if [ -r /etc/default/cis-hardening ]; then
    # shellcheck source=../../debian/default
    . /etc/default/cis-hardening
fi

if [ -z "${CIS_LIB_DIR:-}" ]; then
    echo "There is no /etc/default/cis-hardening file nor CIS_LIB_DIR in environment."
    exit 128
fi

# Main function
if [ -r "${CIS_LIB_DIR}/main.sh" ]; then
    # shellcheck source=../../lib/main.sh
    . "${CIS_LIB_DIR}/main.sh"
else
    echo "Cannot find main.sh in CIS_LIB_DIR=${CIS_LIB_DIR}"
    exit 128
fi
