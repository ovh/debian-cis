#!/bin/bash

# run-shellcheck
#
# OVH Security audit
#

#
# Ensure default deny firewall policy (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Check firewall default policy for DROP on INPUT and FORWARD, using nftables or iptables."

FW_NFT_PKG="nftables"
FW_NFT_CMD="nft"
FW_IPT_PKG="iptables"
FW_IPT_CMD="iptables"
PACKAGES="$FW_NFT_PKG $FW_IPT_PKG"
FW_CHAINS="INPUT FORWARD"
FW_POLICY="DROP"
FW_TIMEOUT="10"

NET_FW_INSTALLED=1
NET_FW_NFT_RULESET=""
NET_FW_IPT_RULESET=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    is_pkg_installed "$FW_NFT_PKG"
    if [ "$FNRET" = 0 ]; then
        NET_FW_INSTALLED=0
        NET_FW_NFT_RULESET=$($SUDO_CMD "$FW_NFT_CMD" list ruleset 2>/dev/null || true)
    fi

    is_pkg_installed "$FW_IPT_PKG"
    if [ "$FNRET" = 0 ]; then
        NET_FW_INSTALLED=0
        NET_FW_IPT_RULESET=$($SUDO_CMD "$FW_IPT_CMD" -nL -w "$FW_TIMEOUT" 2>/dev/null || true)
    fi

    if [ "$NET_FW_INSTALLED" -ne 0 ]; then
        crit "None of the following firewall packages are installed: $PACKAGES"
        return
    fi

    if [ -z "$NET_FW_NFT_RULESET" ] && [ -z "$NET_FW_IPT_RULESET" ]; then
        crit "No firewall rule at all, so no chain has $FW_POLICY as its default policy."
        return
    fi

    local chain hook regex reason found policies
    for chain in $FW_CHAINS; do
        hook=${chain,,}
        found=1
        reason=""

        if [ -n "$NET_FW_IPT_RULESET" ]; then
            regex="Chain $chain \(policy ([A-Z]+)\)"
            # previous line will capture actual policy
            if [[ "$NET_FW_IPT_RULESET" =~ $regex ]]; then
                if [ "${BASH_REMATCH[1]}" = "$FW_POLICY" ]; then
                    found=0
                    ok "Policy correctly set to $FW_POLICY for chain $chain (iptables)"
                else
                    reason="Policy set to ${BASH_REMATCH[1]} for chain $chain (iptables), should be ${FW_POLICY}."
                fi
            else
                reason="Unable to find chain $chain (iptables)"
            fi
        fi

        # A native nftables ruleset is invisible to iptables, so look at it too.
        # An accept verdict does not end the traversal of a hook, so any base
        # chain whose policy is DROP is enough to deny the packet.
        if [ "$found" -ne 0 ] && [ -n "$NET_FW_NFT_RULESET" ]; then
            policies=$(nft_ip_hook_policies "$hook" <<<"$NET_FW_NFT_RULESET" | tr '\n' ' ')
            policies=${policies% }
            if [[ " $policies " == *" $FW_POLICY "* ]]; then
                found=0
                ok "Policy correctly set to $FW_POLICY for chain $chain (nftables)"
            elif [ -n "$policies" ] && [ -z "$reason" ]; then
                reason="Policy set to $policies for chain $chain (nftables), should be ${FW_POLICY}."
            fi
        fi

        if [ "$found" -ne 0 ]; then
            if [ -z "$reason" ]; then
                reason="No base chain registered on hook $hook has $FW_POLICY as its default policy."
            fi
            crit "$reason"
        fi
    done
}

# This function will be called if the script status is on enabled mode
apply() {
    :
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
