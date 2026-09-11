#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure dhcp server services are not in use (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure dhcp server services are not in use."
# shellcheck disable=2034
HARDENING_EXCEPTION=dhcp

PACKAGE='isc-dhcp-server'
SERVICE4='isc-dhcp-server.service'
SERVICE6='isc-dhcp-server6.service'

# Global state (0=true/success, 1=false/failure)
DHCP_PKG_INSTALLED=1
DHCP_PKG_IS_DEPENDENCY=1
DHCP_SERVICE4_ENABLED=1
DHCP_SERVICE4_ACTIVE=1
DHCP_SERVICE6_ENABLED=1
DHCP_SERVICE6_ACTIVE=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    DHCP_PKG_INSTALLED=1
    DHCP_PKG_IS_DEPENDENCY=1
    DHCP_SERVICE4_ENABLED=1
    DHCP_SERVICE4_ACTIVE=1
    DHCP_SERVICE6_ENABLED=1
    DHCP_SERVICE6_ACTIVE=1

    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" -eq 0 ]; then
        DHCP_PKG_INSTALLED=0
    else
        ok "$PACKAGE is not installed"
        return
    fi

    is_pkg_a_dependency "$PACKAGE"
    if [ "$FNRET" -eq 0 ]; then
        DHCP_PKG_IS_DEPENDENCY=0
    fi

    if [ "$DHCP_PKG_IS_DEPENDENCY" -ne 0 ]; then
        crit "$PACKAGE is installed and not a dependency"
        return
    fi

    is_service_enabled "$SERVICE4"
    if [ "$FNRET" -eq 0 ]; then
        DHCP_SERVICE4_ENABLED=0
        crit "$SERVICE4 is enabled"
    fi

    is_service_active "$SERVICE4"
    if [ "$FNRET" -eq 0 ]; then
        DHCP_SERVICE4_ACTIVE=0
        crit "$SERVICE4 is active"
    fi

    is_service_enabled "$SERVICE6"
    if [ "$FNRET" -eq 0 ]; then
        DHCP_SERVICE6_ENABLED=0
        crit "$SERVICE6 is enabled"
    fi

    is_service_active "$SERVICE6"
    if [ "$FNRET" -eq 0 ]; then
        DHCP_SERVICE6_ACTIVE=0
        crit "$SERVICE6 is active"
    fi

    if [ "$DHCP_SERVICE4_ENABLED" -ne 0 ] && [ "$DHCP_SERVICE4_ACTIVE" -ne 0 ] &&
        [ "$DHCP_SERVICE6_ENABLED" -ne 0 ] && [ "$DHCP_SERVICE6_ACTIVE" -ne 0 ]; then
        ok "$PACKAGE is used as a dependency and $SERVICE4/$SERVICE6 are not enabled/active"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$DHCP_PKG_INSTALLED" -ne 0 ]; then
        ok "$PACKAGE is not installed"
        return
    fi

    if [ "$DHCP_PKG_IS_DEPENDENCY" -ne 0 ]; then
        info "$PACKAGE is installed and not a dependency, removing it"
        apt-get purge "$PACKAGE" -y
        apt-get autoremove -y
        return
    fi

    is_systemctl_running
    if [ "$FNRET" -ne 0 ]; then
        warn "systemd not running, cannot stop/mask $SERVICE4 and $SERVICE6"
        return
    fi

    if [ "$DHCP_SERVICE4_ENABLED" -eq 0 ] || [ "$DHCP_SERVICE4_ACTIVE" -eq 0 ] ||
        [ "$DHCP_SERVICE6_ENABLED" -eq 0 ] || [ "$DHCP_SERVICE6_ACTIVE" -eq 0 ]; then
        info "Stopping and masking $SERVICE4 and $SERVICE6"
        systemctl stop "$SERVICE4" "$SERVICE6" || true
        systemctl mask "$SERVICE4" "$SERVICE6"
    else
        ok "$SERVICE4 and $SERVICE6 already not enabled/active"
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
