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

# Global state
TIMESYNCD_INSTALLED=1
CONFIG_OK=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    TIMESYNCD_INSTALLED=1
    CONFIG_OK=1

    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        crit "$PACKAGE is not installed"
        TIMESYNCD_INSTALLED=0
        return
    fi
    ok "$PACKAGE is installed"

    if [ ! -f "$CONFIG_FILE" ]; then
        crit "Timesyncd configuration file $CONFIG_FILE does not exist"
        CONFIG_OK=0
        return
    fi

    # Check NTP servers if configured
    if [ -n "$NTP_SERVERS" ]; then
        does_pattern_exist_in_file "$CONFIG_FILE" "^NTP="
        if [ "$FNRET" != 0 ]; then
            crit "NTP servers not configured in $CONFIG_FILE"
            CONFIG_OK=0
        else
            # Verify the configured servers
            does_pattern_exist_in_file "$CONFIG_FILE" "^NTP=.*$NTP_SERVERS"
            if [ "$FNRET" != 0 ]; then
                crit "NTP servers do not match configured value in $CONFIG_FILE"
                CONFIG_OK=0
            else
                ok "NTP servers correctly configured"
            fi
        fi
    fi

    # Check Fallback NTP servers if configured
    if [ -n "$FALLBACK_NTP_SERVERS" ]; then
        does_pattern_exist_in_file "$CONFIG_FILE" "^FallbackNTP="
        if [ "$FNRET" != 0 ]; then
            crit "FallbackNTP servers not configured in $CONFIG_FILE"
            CONFIG_OK=0
        else
            # Verify the configured servers
            does_pattern_exist_in_file "$CONFIG_FILE" "^FallbackNTP=.*$FALLBACK_NTP_SERVERS"
            if [ "$FNRET" != 0 ]; then
                crit "FallbackNTP servers do not match configured value in $CONFIG_FILE"
                CONFIG_OK=0
            else
                ok "FallbackNTP servers correctly configured"
            fi
        fi
    fi

    if [ "$CONFIG_OK" -eq 1 ]; then
        ok "Timesyncd is properly configured"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$TIMESYNCD_INSTALLED" -eq 0 ]; then
        crit "$PACKAGE is not installed, cannot apply"
        return
    fi

    if [ "$CONFIG_OK" -eq 0 ]; then
        info "Creating timesyncd configuration"
        mkdir -p "$CONFIG_DIR"

        # Create config file with NTP settings
        cat >"$CONFIG_FILE" <<EOF
[Time]
EOF

        if [ -n "$NTP_SERVERS" ]; then
            echo "NTP=$NTP_SERVERS" >>"$CONFIG_FILE"
        fi

        if [ -n "$FALLBACK_NTP_SERVERS" ]; then
            echo "FallbackNTP=$FALLBACK_NTP_SERVERS" >>"$CONFIG_FILE"
        fi

        # Restart timesyncd service
        info "Restarting systemd-timesyncd service"
        systemctl reload-or-restart systemd-timesyncd
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
# Configuration for script: $SCRIPT_NAME
# Put your authorized NTP time servers here (space-separated)
NTP_SERVERS='time.nist.gov time.google.com'
# Fallback NTP servers
FALLBACK_NTP_SERVERS='pool.ntp.org'
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
