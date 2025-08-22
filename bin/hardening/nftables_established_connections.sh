#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure nftables outbound and established connections are configured (Manual)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure nftables outbound and established connections are configured"

NFTABLES_INPUT_ALLOWED=""
NFTABLES_OUTPUT_ALLOWED=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    local status

    for allowed in $NFTABLES_INPUT_ALLOWED; do
        protocol=$(awk -F ':' '{print $1}' <<<"$allowed")
        state=$(awk -F ':' '{print $2}' <<<"$allowed")

        if $SUDO_CMD nft list ruleset 2>/dev/null | awk '/hook input/,/}/' | grep -E "ip protocol $protocol ct state $state accept"; then
            ok "'$protocol' is accepted for state(s) '$state' in nftables 'input'"
        else
            crit "'$protocol' is not accepted for state(s) '$state' in nftables 'input'"
        fi
    done

    for allowed in $NFTABLES_OUTPUT_ALLOWED; do
        protocol=$(awk -F ':' '{print $1}' <<<"$allowed")
        state=$(awk -F ':' '{print $2}' <<<"$allowed")

        if $SUDO_CMD nft list ruleset 2>/dev/null | awk '/hook output/,/}/' | grep -E "ip protocol $protocol ct state $state accept"; then
            ok "'$protocol' is accepted for state(s) '$state' in nftables 'output'"
        else
            crit "'$protocol' is not accepted for state(s) '$state' in nftables 'output'"
        fi
    done

}

# This function will be called if the script status is on enabled mode
apply() {
    info "Please review the rules according to your site policy, and update the check configuration if needed"

}

create_config() {
    cat <<EOF
# shellcheck disable=2034
status=audit
# Put here the input allowed protocols, space separated
# protocol:states
NFTABLES_INPUT_ALLOWED="tcp:established udp:established icmp:established"
NFTABLES_OUTPUT_ALLOWED="tcp:established,related,new udp:established,related,new icmp:established,related,new"
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
