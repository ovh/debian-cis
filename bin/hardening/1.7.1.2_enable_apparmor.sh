#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 1.7.2.2 Ensure AppArmor is enabled in the bootloader configuration (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Activate AppArmor to enforce permissions control."

PACKAGES='apparmor apparmor-utils'

# This function will be called if the script status is on enabled / audit mode
audit() {
    ERROR=0
    for PACKAGE in $PACKAGES; do
        is_pkg_installed "$PACKAGE"
        if [ "$FNRET" != 0 ]; then
            crit "$PACKAGE is absent!"
            ERROR=1
        else
            ok "$PACKAGE is installed"
        fi
    done

    if [ "$ERROR" = 0 ]; then
        is_pkg_installed "grub-common"
        if [ "$FNRET" != 0 ]; then
            if [ "$IS_CONTAINER" -eq 1 ]; then
                ok "Grub is not installed in container"
            else
                warn "Grub is not installed"
                exit 128
            fi
        else
            ERROR=0
            RESULT=$($SUDO_CMD grep "^\s*linux" /boot/grub/grub.cfg)

            # define custom IFS and save default one
            d_IFS=$IFS
            c_IFS=$'\n'
            IFS=$c_IFS
            for line in $RESULT; do
                if [[ ! "$line" =~ "apparmor=1" ]] || [[ ! "$line" =~ "security=apparmor" ]]; then
                    crit "$line is not configured"
                    ERROR=1
                fi
            done
            IFS=$d_IFS
            if [ "$ERROR" = 0 ]; then
                ok "$PACKAGES are configured"

            fi
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    for PACKAGE in $PACKAGES; do
        is_pkg_installed "$PACKAGE"
        if [ "$FNRET" = 0 ]; then
            ok "$PACKAGE is installed"
        else
            crit "$PACKAGE is absent, installing it"
            apt_install "$PACKAGE"
        fi
    done

    is_pkg_installed "grub-pc"
    if [ "$FNRET" != 0 ]; then
        if [ "$IS_CONTAINER" -eq 1 ]; then
            ok "Grub is not installed in container"
        else
            warn "You should use grub. Install it yourself"
        fi
    else
        ERROR=0
        RESULT=$($SUDO_CMD grep "^\s*linux" /boot/grub/grub.cfg)

        # define custom IFS and save default one
        d_IFS=$IFS
        c_IFS=$'\n'
        IFS=$c_IFS
        for line in $RESULT; do
            if [[ ! $line =~ "apparmor=1" ]] || [[ ! $line =~ "security=apparmor" ]]; then
                crit "$line is not configured"
                ERROR=1
            fi
        done
        IFS=$d_IFS

        if [ $ERROR = 1 ]; then
            $SUDO_CMD sed -i "s/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"apparmor=1 security=apparmor /" /etc/default/grub
            $SUDO_CMD update-grub
        else
            ok "$PACKAGES are configured"
        fi
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
