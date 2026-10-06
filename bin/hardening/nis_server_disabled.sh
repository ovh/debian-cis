#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure nis server services are not in use (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Ensure nis server services are not in use."
PACKAGE='ypserv'
SERVICE="ypserv.service"

NIS_PACKAGE_INSTALLED=1
NIS_PACKAGE_IS_DEPENDENCY=1
NIS_SERVICE_ENABLED=1
NIS_SERVICE_ACTIVE=1

# 2 scenarios here:
# - ypserv is a dependency for another package -> disable the service
# - ypserv is not a dependency for another package -> remove the package

# This function will be called if the script status is on enabled / audit mode
audit() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" -eq 0 ]; then
        NIS_PACKAGE_INSTALLED=0 # 0 means package is installed
    fi

    # If package not installed, we're compliant
    if [ "$NIS_PACKAGE_INSTALLED" -ne 0 ]; then
        ok "$PACKAGE is not installed"
        return
    fi

    # Package is installed, check if it's a dependency for other packages
    is_pkg_a_dependency "$PACKAGE"
    if [ "$FNRET" -eq 0 ]; then
        NIS_PACKAGE_IS_DEPENDENCY=0 # 0 means it IS a dependency
    fi

    # Check if service is enabled
    is_service_enabled "$SERVICE"
    if [ "$FNRET" = 0 ]; then
        NIS_SERVICE_ENABLED=0
    fi

    # Check if service is active
    is_service_active "$SERVICE"
    if [ "$FNRET" = 0 ]; then
        NIS_SERVICE_ACTIVE=0
    fi

    if [ "$NIS_PACKAGE_IS_DEPENDENCY" -eq 1 ]; then
        # Package is NOT a dependency, should be removed
        crit "$PACKAGE is installed and should be removed"
    elif [ "$NIS_PACKAGE_IS_DEPENDENCY" -eq 0 ]; then
        # Package IS a dependency, service should be stopped and masked
        if [ "$NIS_SERVICE_ENABLED" -eq 0 ]; then
            crit "$SERVICE is enabled"
        fi

        if [ "$NIS_SERVICE_ACTIVE" -eq 0 ]; then
            crit "$SERVICE is active"
        fi

        if [ "$NIS_SERVICE_ENABLED" -ne 0 ] && [ "$NIS_SERVICE_ACTIVE" -ne 0 ]; then
            ok "$SERVICE is stopped and disabled"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$NIS_PACKAGE_INSTALLED" -ne 0 ]; then
        info "$PACKAGE is not installed, nothing to do"
        return
    fi

    if [ "$NIS_PACKAGE_IS_DEPENDENCY" -eq 1 ]; then
        info "$PACKAGE is installed and not a dependency, removing it"
        DEBIAN_FRONTEND=noninteractive apt-get remove -y "$PACKAGE"
        apt-get autoremove -y || true
    elif [ "$NIS_PACKAGE_IS_DEPENDENCY" -eq 0 ]; then
        # Package is a dependency, stop and mask the service
        if [ "$NIS_SERVICE_ENABLED" -eq 0 ] || [ "$NIS_SERVICE_ACTIVE" -eq 0 ]; then
            is_systemctl_running
            if [ "$FNRET" -ne 0 ]; then
                warn "systemd not running, cannot stop/mask $SERVICE automatically"
                return
            fi
            info "Stopping and masking $SERVICE"
            systemctl stop "$SERVICE" || true
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
