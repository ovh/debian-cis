#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure sshd ClientAliveInterval and ClientAliveCountMax are configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure sshd ClientAliveInterval and ClientAliveCountMax are configured."

PACKAGE='openssh-server'
FILE='/etc/ssh/sshd_config'

# Configurable via etc/conf.d/sshd_idle_timeout.cfg
SSHD_IDLE_CLIENTALIVEINTERVAL=""
SSHD_IDLE_CLIENTALIVECOUNTMAX=""

# Global state (0=compliant, 1=non-compliant)
SSHD_IDLE_PKG_INSTALLED=1
SSHD_IDLE_INTERVAL_OK=1
SSHD_IDLE_COUNTMAX_OK=1

audit() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        ok "$PACKAGE is not installed - not applicable"
        return
    fi
    SSHD_IDLE_PKG_INSTALLED=0
    ok "$PACKAGE is installed"

    # Parse config file directly (sshd -T is unreliable in containers due to Include permissions)
    local l_interval l_countmax
    l_interval=$(grep -Pi '^[[:space:]]*clientaliveinterval\s+' "$FILE" | awk '{print $2}' | head -1 || true)
    l_countmax=$(grep -Pi '^[[:space:]]*clientalivecountmax\s+' "$FILE" | awk '{print $2}' | head -1 || true)

    if [ -z "$l_interval" ] || [ "$l_interval" -le 0 ] 2>/dev/null; then
        crit "ClientAliveInterval is not set or is 0 (effective value: '${l_interval:-unset}')"
    else
        ok "ClientAliveInterval is set to $l_interval"
        SSHD_IDLE_INTERVAL_OK=0
    fi

    if [ -z "$l_countmax" ] || [ "$l_countmax" -le 0 ] 2>/dev/null; then
        crit "ClientAliveCountMax is not set or is 0 (effective value: '${l_countmax:-unset}')"
    else
        ok "ClientAliveCountMax is set to $l_countmax"
        SSHD_IDLE_COUNTMAX_OK=0
    fi
}

apply() {
    if [ "$SSHD_IDLE_PKG_INSTALLED" -ne 0 ]; then
        ok "$PACKAGE is not installed - not applicable"
        return
    fi
    if [ "$SSHD_IDLE_INTERVAL_OK" -eq 0 ] && [ "$SSHD_IDLE_COUNTMAX_OK" -eq 0 ]; then
        return
    fi

    backup_file "$FILE"
    info "Setting ClientAliveInterval to $SSHD_IDLE_CLIENTALIVEINTERVAL in $FILE"
    info "Setting ClientAliveCountMax to $SSHD_IDLE_CLIENTALIVECOUNTMAX in $FILE"

    # Remove existing directives then insert both before the first Include,
    # or append at end if no Include is present. This ensures sshd precedence.
    sed -i '/^[[:space:]]*[Cc]lient[Aa]live[Ii]nterval[[:space:]]/d' "$FILE"
    sed -i '/^[[:space:]]*[Cc]lient[Aa]live[Cc]ount[Mm]ax[[:space:]]/d' "$FILE"

    if grep -qi '^[[:space:]]*Include' "$FILE"; then
        {
            sed '/^[[:space:]]*[Ii]nclude/,$ d' "$FILE"
            echo "ClientAliveInterval $SSHD_IDLE_CLIENTALIVEINTERVAL"
            echo "ClientAliveCountMax $SSHD_IDLE_CLIENTALIVECOUNTMAX"
            sed -n '/^[[:space:]]*[Ii]nclude/,$ p' "$FILE"
        } >"${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"
    else
        echo "ClientAliveInterval $SSHD_IDLE_CLIENTALIVEINTERVAL" >>"$FILE"
        echo "ClientAliveCountMax $SSHD_IDLE_CLIENTALIVECOUNTMAX" >>"$FILE"
    fi

    if sshd -t 2>/dev/null; then
        info "sshd configuration is valid"
        systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true
    else
        warn "sshd configuration test failed after modification - please review $FILE"
    fi
}

check_config() {
    if [ -z "$SSHD_IDLE_CLIENTALIVEINTERVAL" ] || [ "$SSHD_IDLE_CLIENTALIVEINTERVAL" -le 0 ] 2>/dev/null; then
        SSHD_IDLE_CLIENTALIVEINTERVAL=15
    fi
    if [ -z "$SSHD_IDLE_CLIENTALIVECOUNTMAX" ] || [ "$SSHD_IDLE_CLIENTALIVECOUNTMAX" -le 0 ] 2>/dev/null; then
        SSHD_IDLE_CLIENTALIVECOUNTMAX=3
    fi
}

create_config() {
    cat <<EOF
status=audit
# ClientAliveInterval: seconds between keepalive probes (must be > 0)
# ClientAliveCountMax: number of probes before disconnection (must be > 0)
# Default: 15s interval × 3 probes = ~45s idle timeout
SSHD_IDLE_CLIENTALIVEINTERVAL=15
SSHD_IDLE_CLIENTALIVECOUNTMAX=3
EOF
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
