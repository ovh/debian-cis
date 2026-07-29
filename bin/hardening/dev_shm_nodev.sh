#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure nodev option set on /dev/shm partition (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure nodev option set on /dev/shm partition."

PARTITION="/dev/shm"
OPTION="nodev"

# Global state (0=success, 1=failure)
DEV_SHM_NODEV_IS_PARTITION=1
DEV_SHM_NODEV_FSTAB_HAS_OPTION=1
DEV_SHM_NODEV_MOUNTED_WITH_OPTION=1

# Check function to populate state
dev_shm_nodev_check() {
    DEV_SHM_NODEV_IS_PARTITION=1
    DEV_SHM_NODEV_FSTAB_HAS_OPTION=1
    DEV_SHM_NODEV_MOUNTED_WITH_OPTION=1

    is_a_partition "$PARTITION"
    if [ "$FNRET" -eq 0 ]; then
        # Is a partition (0=is partition/success)
        DEV_SHM_NODEV_IS_PARTITION=0
    else
        # Not a partition (1=not a partition/failure)
        return
    fi

    has_mount_option "$PARTITION" "$OPTION"
    if [ "$FNRET" -eq 0 ]; then
        # Has option in fstab (0=has option/success)
        DEV_SHM_NODEV_FSTAB_HAS_OPTION=0
    fi

    has_mounted_option "$PARTITION" "$OPTION"
    if [ "$FNRET" -eq 0 ]; then
        # Mounted with option (0=mounted with option/success)
        DEV_SHM_NODEV_MOUNTED_WITH_OPTION=0
    fi
}

# This function will be called if the script status is on enabled / audit mode
audit() {
    dev_shm_nodev_check

    if [ "$DEV_SHM_NODEV_IS_PARTITION" -ne 0 ]; then
        crit "$PARTITION is not a partition"
        return
    fi

    if [ "$DEV_SHM_NODEV_FSTAB_HAS_OPTION" -ne 0 ]; then
        crit "$PARTITION has no option $OPTION in fstab!"
    else
        ok "$PARTITION has $OPTION in fstab"
    fi

    if [ "$DEV_SHM_NODEV_MOUNTED_WITH_OPTION" -ne 0 ]; then
        warn "$PARTITION is not mounted with $OPTION at runtime"
    else
        ok "$PARTITION mounted with $OPTION"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$DEV_SHM_NODEV_IS_PARTITION" -ne 0 ]; then
        crit "$PARTITION is not a partition, cannot apply"
        return
    fi

    if [ "$DEV_SHM_NODEV_FSTAB_HAS_OPTION" -ne 0 ]; then
        info "Adding $OPTION to $PARTITION in fstab"
        add_option_to_fstab "$PARTITION" "$OPTION"
    fi

    if [ "$DEV_SHM_NODEV_MOUNTED_WITH_OPTION" -ne 0 ]; then
        info "Remounting $PARTITION with $OPTION"
        remount_partition "$PARTITION"
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
if [ -z "${CIS_LIB_DIR}" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_LIB_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r "${CIS_LIB_DIR}"/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "${CIS_LIB_DIR}"/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is ${CIS_LIB_DIR} in /etc/default/cis-hardening"
    exit 128
fi
