#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure strong password hashing algorithm is configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure strong password hashing algorithm is configured in /etc/login.defs."

CONF_FILE="/etc/login.defs"

# Configurable: may be overridden via check_config()
# Space-separated list of accepted algorithms for audit
ALD_ALLOWED_ALGORITHMS=""
# Algorithm to write when applying the fix
ALD_ENCRYPT_METHOD=""

# Global state
ALD_HASH_CONFIGURED=1 # 1 = non-compliant, 0 = compliant

# This function will be called if the script status is on enabled / audit mode
audit() {
    if $SUDO_CMD [ ! -r "$CONF_FILE" ]; then
        crit "$CONF_FILE is not readable"
        return
    fi

    # Build a regex alternation from the allow-list (e.g. "SHA512 YESCRYPT" → "SHA512|YESCRYPT")
    local l_pattern
    l_pattern=$(echo "$ALD_ALLOWED_ALGORITHMS" | tr ' ' '|')

    if $SUDO_CMD grep -Pi -- "^\\h*ENCRYPT_METHOD\\h+(${l_pattern})\\b" "$CONF_FILE" >/dev/null 2>&1; then
        ok "ENCRYPT_METHOD is set to an approved algorithm ($ALD_ALLOWED_ALGORITHMS) in $CONF_FILE"
        ALD_HASH_CONFIGURED=0
    else
        crit "ENCRYPT_METHOD is not set to an approved algorithm ($ALD_ALLOWED_ALGORITHMS) in $CONF_FILE"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$ALD_HASH_CONFIGURED" -eq 0 ]; then
        ok "ENCRYPT_METHOD already set to a strong algorithm"
        return
    fi

    if [ ! -r "$CONF_FILE" ]; then
        warn "$CONF_FILE is not readable - cannot apply"
        return
    fi

    backup_file "$CONF_FILE"
    info "Setting ENCRYPT_METHOD to $ALD_ENCRYPT_METHOD in $CONF_FILE"
    if grep -qi '^[[:space:]]*ENCRYPT_METHOD[[:space:]]' "$CONF_FILE"; then
        replace_in_file "$CONF_FILE" '^ENCRYPT_METHOD[[:space:]]*.*' "ENCRYPT_METHOD $ALD_ENCRYPT_METHOD"
    else
        add_end_of_file "$CONF_FILE" "ENCRYPT_METHOD $ALD_ENCRYPT_METHOD"
    fi
}

# This function will check config parameters required
check_config() {
    if [ -z "$ALD_ALLOWED_ALGORITHMS" ]; then
        ALD_ALLOWED_ALGORITHMS="SHA512 YESCRYPT"
    fi
    if [ -z "$ALD_ENCRYPT_METHOD" ]; then
        ALD_ENCRYPT_METHOD="YESCRYPT"
    fi
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit
# Configurable: space-separated list of allowed hashing algorithms for audit
ALD_ALLOWED_ALGORITHMS='SHA512 YESCRYPT'
# Algorithm to write when applying the fix
ALD_ENCRYPT_METHOD='YESCRYPT'
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
