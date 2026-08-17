#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure local login warning banner is configured properly (Automated)
#

set -e
set -u

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Ensure local login warning banner is configured properly"

BLB_FILE='/etc/issue'
BLB_DISTRO_NAME=''
BLB_PATTERN_OK=1

audit() {
    if [ ! -f "$BLB_FILE" ]; then
        crit "$BLB_FILE does not exist"
        return
    fi

    # Get the distro name from /etc/os-release
    if [ -f /etc/os-release ]; then
        BLB_DISTRO_NAME=$(grep '^ID=' /etc/os-release | cut -d= -f2 | sed -e 's/"//g')
    fi

    # Check for OS information patterns: \v, \r, \m, \s and distro name
    # Build the pattern: (\v|\r|\m|\s|distro_name)
    local pattern="(\\\\v|\\\\r|\\\\m|\\\\s"
    if [ -n "$BLB_DISTRO_NAME" ]; then
        pattern="${pattern}|${BLB_DISTRO_NAME}"
    fi
    pattern="${pattern})"

    if grep -E -i "$pattern" "$BLB_FILE" >/dev/null 2>&1; then
        crit "OS information patterns found in $BLB_FILE"
        BLB_PATTERN_OK=1
    else
        ok "No OS information patterns found in $BLB_FILE"
        BLB_PATTERN_OK=0
    fi
}

apply() {
    if [ ! -f "$BLB_FILE" ]; then
        warn "$BLB_FILE does not exist, creating with default banner"
        cat >"$BLB_FILE" <<'EOF'
Authorized access to this system is restricted to authorized users only.
All activity is monitored and logged.
By accessing this system, you agree that your actions may be monitored and recorded.
Unauthorized access attempts will be logged and may result in legal action.
EOF
        return
    fi

    if [ "$BLB_PATTERN_OK" -ne 0 ]; then
        backup_file "$BLB_FILE"

        # Remove lines containing backslash and v/r/m/s (mingetty escape sequences)
        sed -i '/\\v/d; /\\r/d; /\\m/d; /\\s/d' "$BLB_FILE" || true

        # Remove lines containing the distro name (case-insensitive)
        if [ -n "$BLB_DISTRO_NAME" ]; then
            sed -i "/${BLB_DISTRO_NAME}/I d" "$BLB_FILE" || true
        fi

        info "Removed OS information from $BLB_FILE"
    fi
}

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
