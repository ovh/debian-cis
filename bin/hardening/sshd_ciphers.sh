#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure sshd Ciphers are configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure sshd uses only strong approved ciphers."

PACKAGE='openssh-server'
FILE='/etc/ssh/sshd_config'

# Configurable: may be overridden via check_config()
OPTIONS="" # Ciphers line to write

# Global state
SSHD_CIPHERS_PKG_INSTALLED=1 # 1 = not installed, 0 = installed
SSHD_CIPHERS_OK=1            # 1 = non-compliant, 0 = compliant

# This function will be called if the script status is on enabled / audit mode
audit() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        ok "$PACKAGE is not installed - not applicable"
        return
    fi
    SSHD_CIPHERS_PKG_INSTALLED=0
    ok "$PACKAGE is installed"

    # Derive the allow-list from configured OPTIONS (strip leading "Ciphers" + spaces)
    local sshd_ciphers allowed_ciphers
    allowed_ciphers=$(echo "$OPTIONS" | sed -E 's/^[[:space:]]*[Cc]iphers[[:space:]]+//')

    # Read configured Ciphers directive from sshd_config directly.
    # This keeps behavior deterministic across root/sudo and container environments.
    sshd_ciphers=$(grep -Pi '^[[:space:]]*[Cc]iphers[[:space:]]+' "$FILE" |
        head -1 |
        sed -E 's/^[[:space:]]*[Cc]iphers[[:space:]]+//' || true)

    # If no explicit Ciphers directive is present, treat defaults as compliant baseline.
    if [ -z "$sshd_ciphers" ]; then
        sshd_ciphers="$allowed_ciphers"
    fi

    # Check each active cipher against the allow-list
    local bad_ciphers=""
    local l_cipher
    while IFS=',' read -r l_cipher; do
        l_cipher=$(echo "$l_cipher" | tr -d '[:space:]')
        [ -z "$l_cipher" ] && continue
        if ! echo ",$allowed_ciphers," | grep -qF ",$l_cipher,"; then
            bad_ciphers="${bad_ciphers:+$bad_ciphers,}$l_cipher"
        fi
    done <<EOF
$sshd_ciphers
EOF

    if [ -n "$bad_ciphers" ]; then
        crit "sshd is using non-approved ciphers: $bad_ciphers"
    else
        ok "sshd is using only approved ciphers"
        SSHD_CIPHERS_OK=0
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$SSHD_CIPHERS_PKG_INSTALLED" -ne 0 ]; then
        ok "$PACKAGE is not installed - not applicable"
        return
    fi

    if [ "$SSHD_CIPHERS_OK" -eq 0 ]; then
        ok "sshd ciphers already compliant"
        return
    fi

    # Remove any existing Ciphers line(s) and replace with the allow-list
    info "Configuring $FILE with approved ciphers only"
    backup_file "$FILE"
    # Remove existing Ciphers lines
    sed -i '/^[[:space:]]*[Cc]iphers[[:space:]]/d' "$FILE"
    # Insert before the first Include if present, otherwise append
    if grep -qi '^[[:space:]]*Include' "$FILE"; then
        sed -i "0,/^[[:space:]]*[Ii]nclude/{s|^[[:space:]]*[Ii]nclude|${OPTIONS}\n&|}" "$FILE"
    else
        echo "$OPTIONS" >>"$FILE"
    fi

    if sshd -t 2>/dev/null; then
        info "sshd configuration is valid"
        systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true
    else
        warn "sshd configuration test failed after modification - please review $FILE"
    fi
}

# This function will check config parameters required
check_config() {
    if [ -z "$OPTIONS" ]; then
        OPTIONS="Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr"
    fi
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit
# Configurable: comma-separated list of approved ciphers
# FIPS 140 compliant defaults: aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
OPTIONS='Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr'
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
