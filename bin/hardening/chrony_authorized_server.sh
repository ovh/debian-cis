#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure chrony is configured with authorized timeserver (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure chrony is configured with authorized timeserver."

PACKAGE='chrony'
SOURCES_DIR='/etc/chrony/sources.d'
SOURCES_FILE="$SOURCES_DIR/authorized.sources"
MAIN_CONF='/etc/chrony/chrony.conf'

# Configurable via create_config
CHRONY_TIME_SOURCES=''

# Global state (0=success, 1=failure)
CHRONY_AUTH_PKG_INSTALLED=1
CHRONY_AUTH_CONFIG_OK=1

# Check function to populate state
chrony_auth_check() {
    CHRONY_AUTH_PKG_INSTALLED=1
    CHRONY_AUTH_CONFIG_OK=1

    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        # Package not installed (1=not installed/failure)
        CHRONY_AUTH_PKG_INSTALLED=1
        return
    fi
    # Package is installed (0=installed/success)
    CHRONY_AUTH_PKG_INSTALLED=0

    # Check if sources.d directory is included in main config
    if [ -f "$MAIN_CONF" ]; then
        does_pattern_exist_in_file "$MAIN_CONF" "^sourcedir.*$SOURCES_DIR"
        if [ "$FNRET" != 0 ]; then
            # sourcedir not configured (1=not OK/failure)
            CHRONY_AUTH_CONFIG_OK=1
            return
        fi
    else
        # Main config not found (1=not OK/failure)
        CHRONY_AUTH_CONFIG_OK=1
        return
    fi

    # Check sources file
    if [ ! -f "$SOURCES_FILE" ]; then
        # Sources file doesn't exist (1=not OK/failure)
        CHRONY_AUTH_CONFIG_OK=1
        return
    fi

    if [ -z "$CHRONY_TIME_SOURCES" ]; then
        # Cannot verify without configured sources (1=not OK/failure)
        CHRONY_AUTH_CONFIG_OK=1
        return
    fi

    # Check if configured sources are present
    does_pattern_exist_in_file "$SOURCES_FILE" "$CHRONY_TIME_SOURCES"
    if [ "$FNRET" != 0 ]; then
        # Sources not found (1=not OK/failure)
        CHRONY_AUTH_CONFIG_OK=1
        return
    fi

    # All checks passed (0=OK/success)
    CHRONY_AUTH_CONFIG_OK=0
}

# This function will be called if the script status is on enabled / audit mode
audit() {
    chrony_auth_check

    if [ "$CHRONY_AUTH_PKG_INSTALLED" -ne 0 ]; then
        crit "$PACKAGE is not installed"
        return
    fi
    ok "$PACKAGE is installed"

    if [ "$CHRONY_AUTH_CONFIG_OK" -ne 0 ]; then
        crit "Chrony configuration is not correct"
    else
        ok "Time sources correctly configured"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$CHRONY_AUTH_PKG_INSTALLED" -ne 0 ]; then
        crit "$PACKAGE is not installed, cannot apply"
        return
    fi

    if [ "$CHRONY_AUTH_CONFIG_OK" -ne 0 ]; then
        # Ensure sourcedir directive exists in main config
        info "Ensuring sourcedir is configured in $MAIN_CONF"
        if [ -f "$MAIN_CONF" ]; then
            does_pattern_exist_in_file "$MAIN_CONF" "^sourcedir.*$SOURCES_DIR"
            if [ "$FNRET" != 0 ]; then
                backup_file "$MAIN_CONF"
                add_end_of_file "$MAIN_CONF" "sourcedir $SOURCES_DIR"
            fi
        fi

        # Create sources directory and file
        info "Creating chrony sources configuration"
        mkdir -p "$SOURCES_DIR"

        if [ -n "$CHRONY_TIME_SOURCES" ]; then
            echo "$CHRONY_TIME_SOURCES" >"$SOURCES_FILE"
        fi

        # Restart chronyd service
        info "Restarting chronyd service"
        is_systemctl_running
        if [ "$FNRET" = 0 ]; then
            systemctl restart chronyd
        else
            info "Systemd is not running, skipping service restart"
        fi
    else
        ok "Chrony configuration already correct"
    fi
}

# This function will check config parameters required
check_config() {
    if [ -z "$CHRONY_TIME_SOURCES" ]; then
        crit "CHRONY_TIME_SOURCES is not configured"
        exit 128
    fi
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit
# Configuration for script: $SCRIPT_NAME
# Put your authorized NTP time servers here in chrony.sources format
# Example: pool 2.debian.pool.ntp.org iburst
CHRONY_TIME_SOURCES='pool 2.debian.pool.ntp.org iburst'
EOF
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
