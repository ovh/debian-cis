#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure network file system services are not in use (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure network file system services are not in use."
# shellcheck disable=2034
HARDENING_EXCEPTION=nfs

PACKAGE='nfs-kernel-server'
SERVICE='nfs-server.service'

# 2 scenario here:
# - nfs-kernel-server is a dependency for another package -> disable the service
# - nfs-kernel-server is not a dependency for another package -> remove the package

# This function will be called if the script status is on enabled / audit mode
audit() {
    PACKAGE_INSTALLED=1
    PACKAGE_IS_DEPENDENCY=1
    SERVICE_ENABLED=1
    SERVICE_ACTIVE=1

    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" -eq 0 ]; then
        PACKAGE_INSTALLED=0
    fi

    is_pkg_a_dependency "$PACKAGE"
    if [ "$FNRET" -eq 0 ]; then
        PACKAGE_IS_DEPENDENCY=0
    fi

    is_service_enabled "$SERVICE"
    if [ "$FNRET" -eq 0 ]; then
        SERVICE_ENABLED=0
    fi

    is_service_active "$SERVICE"
    if [ "$FNRET" -eq 0 ]; then
        SERVICE_ACTIVE=0
    fi

    if [ "$PACKAGE_INSTALLED" -eq 0 ] && [ "$PACKAGE_IS_DEPENDENCY" -eq 1 ]; then
        crit "$PACKAGE is installed and not a dependency"

    elif [ "$PACKAGE_INSTALLED" -eq 0 ] && [ "$PACKAGE_IS_DEPENDENCY" -eq 0 ]; then
        active=1
        if [ "$SERVICE_ENABLED" -eq 0 ]; then
            active=0
            crit "$SERVICE is enabled"
        fi

        if [ "$SERVICE_ACTIVE" -eq 0 ]; then
            active=0
            crit "$SERVICE is active"
        fi

        if [ "$active" -eq 1 ]; then
            ok "$PACKAGE is not used"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$PACKAGE_INSTALLED" -eq 0 ] && [ "$PACKAGE_IS_DEPENDENCY" -eq 1 ]; then
        crit "$PACKAGE is installed and not a dependency, removing it"
        apt_remove "$PACKAGE" -y
        apt-get autoremove -y
    elif [ "$PACKAGE_INSTALLED" -eq 0 ] && [ "$PACKAGE_IS_DEPENDENCY" -eq 0 ]; then
        if [ "$SERVICE_ENABLED" -eq 0 ] || [ "$SERVICE_ACTIVE" -eq 0 ]; then
            info "Stopping and masking $SERVICE"
            systemctl stop "$SERVICE"
            systemctl mask "$SERVICE"
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
