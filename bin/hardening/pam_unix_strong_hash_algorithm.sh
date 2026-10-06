#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure pam_unix includes a strong password hashing algorithm (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Ensure pam_unix includes a strong password hashing algorithm."

# Global state
PUH_HASH_CONFIGURED=1 # 1 = not configured, 0 = configured
PUH_CONFIG_FILE="/etc/pam.d/common-password"

# This function will be called if the script status is on enabled / audit mode
audit() {
    if [ ! -f "$PUH_CONFIG_FILE" ]; then
        info "$PUH_CONFIG_FILE does not exist - PAM not configured or using alternative setup"
        return
    fi

    # Search for password line with pam_unix.so containing sha512 or yescrypt
    # Pattern: "password" followed by spaces, "pam_unix.so", and either "sha512" or "yescrypt"
    if grep -P '^[[:space:]]*password\h+([^#\r\n]+)\h+pam_unix\.so(\h+[^#\r\n]+)?\h+(sha512|yescrypt)\b' "$PUH_CONFIG_FILE" >/dev/null 2>&1; then
        ok "pam_unix.so configured with sha512 or yescrypt in $PUH_CONFIG_FILE"
        PUH_HASH_CONFIGURED=0
    else
        crit "pam_unix.so not configured with sha512 or yescrypt in $PUH_CONFIG_FILE"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$PUH_HASH_CONFIGURED" -eq 0 ]; then
        info "pam_unix already configured with strong hashing algorithm"
        return
    fi

    if [ ! -f "$PUH_CONFIG_FILE" ]; then
        warn "$PUH_CONFIG_FILE does not exist"
        return
    fi

    # Find and modify the PAM source configuration
    local unix_profile="/usr/share/pam-configs/unix"

    if [ ! -f "$unix_profile" ]; then
        warn "Could not find $unix_profile for modification"
        return
    fi

    # Check if sha512 or yescrypt is already present in the profile
    if grep -qE 'sha512|yescrypt' "$unix_profile"; then
        info "$unix_profile already contains sha512 or yescrypt"
    else
        info "Adding sha512 to pam_unix.so in Password section of $unix_profile"

        # Use sed to add sha512 to pam_unix.so line in Password-Type section
        # This handles multiline password section by finding Password-Type line
        # and modifying pam_unix.so until the next -Type: line
        sed -i '/^Password-Type:/,/^[A-Z].*-Type:/ {
            /pam_unix\.so/ {
                /sha512\|yescrypt/ ! s/$/\n sha512/
            }
        }' "$unix_profile"
    fi

    # Apply profile changes first when pam-auth-update is available.
    if command -v pam-auth-update >/dev/null 2>&1; then
        info "Running pam-auth-update to apply PAM configuration changes"
        DEBIAN_FRONTEND='noninteractive' pam-auth-update --force --enable unix >/dev/null 2>&1 || true
    fi

    # Enforce strong hash in the effective file audited by this script.
    if grep -E 'password\s+.*pam_unix\.so' "$PUH_CONFIG_FILE" >/dev/null 2>&1; then
        info "Enforcing yescrypt on pam_unix.so line(s) in $PUH_CONFIG_FILE"
        sed -Ei '/^[[:space:]]*password[[:space:]]+.*pam_unix\.so/ {
            s/([[:space:]])(md5|bigcrypt|sha256|sha512|blowfish|gost_yescrypt|yescrypt)([[:space:]]|$)/\1/g
            s/[[:space:]]+$/ /
            /(^|[[:space:]])yescrypt([[:space:]]|$)/! s/$/ yescrypt/
        }' "$PUH_CONFIG_FILE"
    else
        info "No pam_unix.so password line found in $PUH_CONFIG_FILE, adding one"
        add_line_file_before_pattern "$PUH_CONFIG_FILE" "password [success=1 default=ignore] pam_unix.so yescrypt" "# pam-auth-update(8) for details."
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
