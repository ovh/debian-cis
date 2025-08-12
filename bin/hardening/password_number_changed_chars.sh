#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure password number of changed characters is configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure password number of changed characters is configured"

OPTIONS=''

# This function will be called if the script status is on enabled / audit mode
audit() {
    QUALITY_VALID=1
    DIFOK_IN_PAM=1

    # order of override from strongest to latest:
    # - /etc/pam.d/*
    # - /etc/security/pwquality.conf
    # - /etc/security/pwquality.conf.d/*.conf
    # "It is recommended that settings be configured in a .conf file in the /etc/security/pwquality.conf.d/ directory for clarity, convenience, and durability."
    expected_value=$(awk -F '=' '{print $2}' <<<"$OPTIONS")

    local difok_value=""
    DIFOK_FILE="/etc/security/pwquality.conf"

    if [ -d /etc/security/pwquality.conf.d ]; then
        if grep -E "^[[:space:]]?difok" /etc/security/pwquality.conf.d/*.conf >/dev/null 2>&1; then
            # if set in many places, the latest one is the one used
            DIFOK_FILE=$(grep -lE "^[[:space:]]?difok" | sort -n | tail -n 1)
        fi
    fi

    # maybe absent from /etc/security/pwquality.conf
    if grep -E "^[[:space:]]?difok" "$DIFOK_FILE" >/dev/null 2>&1; then
        difok_value=$(grep -E "^[[:space:]]?difok" "$DIFOK_FILE" | awk -F '=' '{print $2}' | sed 's/\ *//g')
        info "current 'pwquality difok' value = $difok_value"

        if [ "$difok_value" -eq "$expected_value" ]; then
            QUALITY_VALID=0
        fi
    fi

    for file in /usr/share/pam-configs/*; do
        if grep -Pl -- '\bpam_pwquality\.so\h+([^#\n\r]+\h+)?difok\b' "$file" >/dev/null 2>&1; then
            DIFOK_IN_PAM=0
            break
        fi
    done

    if [ "$QUALITY_VALID" -eq 0 ]; then
        ok "pwquality 'difok' value is correctly configured"
    else
        crit "pwquality 'difok' value is not correctly configured"
    fi

    if [ "$DIFOK_IN_PAM" -eq 0 ]; then
        crit "pwquality 'difok' is overriden in pam configuration"
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$QUALITY_VALID" -ne 0 ]; then
        sed -E -i '/^[[:space:]]?difok/d' "$DIFOK_FILE"
        echo "$OPTIONS" >>"$DIFOK_FILE"
    fi

    if [ "$DIFOK_IN_PAM" -eq 0 ]; then
        for file in /usr/share/pam-configs/*; do
            if grep -Pl -- '\bpam_pwquality\.so\h+([^#\n\r]+\h+)?difok\b' "$file" >/dev/null 2>&1; then
                sed -E -i 's/difok[[:space:]]?=[[:space:]]?[0-9]+//g' "$file"
            fi
        done
    fi

}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit
# Put your custom configuration here
OPTIONS="difok=2"
EOF
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
