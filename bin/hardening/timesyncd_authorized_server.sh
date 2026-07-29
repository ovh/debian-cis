#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure systemd-timesyncd configured with authorized timeserver (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure systemd-timesyncd configured with authorized timeserver."

PACKAGE='systemd-timesyncd'
CONFIG_DIR='/etc/systemd/timesyncd.conf.d'
CONFIG_FILE="$CONFIG_DIR/50-timesyncd.conf"

# Configurable via create_config
NTP_SERVERS=''
FALLBACK_NTP_SERVERS=''

# Global state (0=success, 1=failure)
TIMESYNCD_AUTH_PKG_INSTALLED=1
TIMESYNCD_AUTH_CONFIG_OK=1

# Check function to populate state
timesyncd_auth_check() {
    TIMESYNCD_AUTH_PKG_INSTALLED=1
    TIMESYNCD_AUTH_CONFIG_OK=1

    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        # Package not installed (1=not installed/failure)
        TIMESYNCD_AUTH_PKG_INSTALLED=1
        return
    fi
    # Package is installed (0=installed/success)
    TIMESYNCD_AUTH_PKG_INSTALLED=0

    if [ ! -f "$CONFIG_FILE" ]; then
        # Config not OK (1=not OK/failure)
        return
    fi

    # Check NTP servers if configured
    if [ -n "$NTP_SERVERS" ]; then
        does_pattern_exist_in_file "$CONFIG_FILE" "^NTP="
        if [ "$FNRET" != 0 ]; then
            # NTP line not found (1=not OK/failure)
            return
        fi
        # Verify the configured servers
        does_pattern_exist_in_file "$CONFIG_FILE" "^NTP=.*$NTP_SERVERS"
        if [ "$FNRET" != 0 ]; then
            # Configured servers not found (1=not OK/failure)
            return
        fi
    fi

    # Check Fallback NTP servers if configured
    if [ -n "$FALLBACK_NTP_SERVERS" ]; then
        does_pattern_exist_in_file "$CONFIG_FILE" "^FallbackNTP="
        if [ "$FNRET" != 0 ]; then
            # FallbackNTP line not found (1=not OK/failure)
            return
        fi
        # Verify the configured servers
        does_pattern_exist_in_file "$CONFIG_FILE" "^FallbackNTP=.*$FALLBACK_NTP_SERVERS"
        if [ "$FNRET" != 0 ]; then
            # Configured fallback servers not found (1=not OK/failure)
            return
        fi
    fi

    # All checks passed (0=OK/success)
    TIMESYNCD_AUTH_CONFIG_OK=0
}

# This function will be called if the script status is on enabled / audit mode
audit() {
    timesyncd_auth_check

    if [ "$TIMESYNCD_AUTH_PKG_INSTALLED" -ne 0 ]; then
        crit "$PACKAGE is not installed"
        return
    fi
    ok "$PACKAGE is installed"

    if [ "$TIMESYNCD_AUTH_CONFIG_OK" -ne 0 ]; then
        crit "Timesyncd configuration is not correct"
    else
        ok "Timesyncd is properly configured"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$TIMESYNCD_AUTH_PKG_INSTALLED" -ne 0 ]; then
        crit "$PACKAGE is not installed, cannot apply"
        return
    fi

    if [ "$TIMESYNCD_AUTH_CONFIG_OK" -ne 0 ]; then
        info "Creating timesyncd configuration"
        mkdir -p "$CONFIG_DIR"

        # Remove existing keys to avoid duplicates
        if [ -f "$CONFIG_FILE" ]; then
            backup_file "$CONFIG_FILE"
            delete_line_in_file "$CONFIG_FILE" "^NTP="
            delete_line_in_file "$CONFIG_FILE" "^FallbackNTP="
        else
            # Create new file with [Time] section
            cat >"$CONFIG_FILE" <<EOF
[Time]
EOF
        fi

        # Add configured values
        if [ -n "$NTP_SERVERS" ]; then
            add_end_of_file "$CONFIG_FILE" "NTP=$NTP_SERVERS"
        fi

        if [ -n "$FALLBACK_NTP_SERVERS" ]; then
            add_end_of_file "$CONFIG_FILE" "FallbackNTP=$FALLBACK_NTP_SERVERS"
        fi

        # Restart timesyncd service
        info "Restarting systemd-timesyncd service"
        is_systemctl_running
        if [ "$FNRET" = 0 ]; then
            systemctl reload-or-restart systemd-timesyncd
        else
            info "Systemd is not running, skipping service restart"
        fi
    else
        ok "Timesyncd configuration already correct"
    fi
}

# This function will check config parameters required
check_config() {
    if [ -z "$NTP_SERVERS" ] && [ -z "$FALLBACK_NTP_SERVERS" ]; then
        crit "Neither NTP_SERVERS nor FALLBACK_NTP_SERVERS is configured"
        exit 128
    fi
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit
# Configuration for script: $SCRIPT_NAME
# Put your authorized NTP time servers here (space-separated)
NTP_SERVERS='1.debian.pool.ntp.org  2.debian.pool.ntp.org 3.debian.pool.ntp.org'
# Fallback NTP servers
FALLBACK_NTP_SERVERS='1.fr.pool.ntp.org'
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
