#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure nftables rules are permanent (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure nftables rules are permanent"
NFTABLES_CONF="/etc/nftables.conf"

# default to "/etc/nftables.rules"
# May be changed in config, see "create_config" below
NFTABLES_RULES=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    NFTABLES_INCLUDE=1
    NFTABLES_INCLUDE_INPUT=1
    NFTABLES_INCLUDE_OUTPUT=1
    NFTABLES_INCLUDE_FORWARD=1
    # the CIS recommendation is to have one or many nftables rules outside nftables.conf
    if grep -E '^\s*include' "$NFTABLES_CONF" >/dev/null; then
        NFTABLES_INCLUDE=0
        ok "There is an included file in $NFTABLES_CONF"

        # shellcheck disable=2046
        if [ $(awk '/hook input/,/}/' $(awk '$1 ~ /^\s*include/ { gsub("\"","",$2);print $2 }' $NFTABLES_CONF) | wc -l) -gt 0 ]; then
            NFTABLES_INCLUDE_INPUT=0
            ok "nftables input is configured to be persistent"
        else
            crit "nftables input is not configured to be persistent"
        fi

        # shellcheck disable=2046
        if [ $(awk '/hook forward/,/}/' $(awk '$1 ~ /^\s*include/ { gsub("\"","",$2);print $2 }' $NFTABLES_CONF) | wc -l) -gt 0 ]; then
            NFTABLES_INCLUDE_FORWARD=0
            ok "nftables forward is configured to be persistent"
        else
            crit "nftables forward is not configured to be persistent"
        fi

        # shellcheck disable=2046
        if [ $(awk '/hook output/,/}/' $(awk '$1 ~ /^\s*include/ { gsub("\"","",$2);print $2 }' $NFTABLES_CONF) | wc -l) -gt 0 ]; then
            NFTABLES_INCLUDE_OUTPUT=0
            ok "nftables output is configured to be persistent"
        else
            crit "nftables output is not configured to be persistent"
        fi

    else
        crit "There is no 'include' in $NFTABLES_CONF"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$NFTABLES_INCLUDE" -ne 0 ]; then
        add_end_of_file "$NFTABLES_CONF" "include \"$NFTABLES_RULES\""
    fi

    if [ "$NFTABLES_INCLUDE_INPUT" -ne 0 ] || [ "$NFTABLES_INCLUDE_FORWARD" -ne 0 ] || [ "$NFTABLES_INCLUDE_OUTPUT" -ne 0 ]; then
        if [ ! -s "$NFTABLES_RULES" ]; then
            nft list ruleset >"$NFTABLES_RULES"
        else
            # we are not going to erase what is already configured, we don't know if the loaded configuration is correct
            info "some basic chains are not persisted in $NFTABLES_RULES, please make sure to add them manually"
        fi
    fi

}

create_config() {
    cat <<EOF
# shellcheck disable=2034
status=audit
# Put here the nftables rules file for persistent rules
NFTABLES_RULES="/etc/nftables.rules"
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
