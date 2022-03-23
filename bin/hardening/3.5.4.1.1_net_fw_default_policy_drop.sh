#!/bin/bash

# run-shellcheck
#
# OVH Security audit
#

#
# 3.5.4.1.1 Ensure default deny firewall policy (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Check iptables firewall default policy for DROP on INPUT and FORWARD."

PACKAGE="iptables"
FW_CHAINS="INPUT FORWARD"
FW_POLICY="DROP"
FW_CMD="iptables"
FW_TIMEOUT="10"

# This function will be called if the script status is on enabled / audit mode
audit() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        crit "$PACKAGE is not installed!"
    else
        ipt=$($SUDO_CMD "$FW_CMD" -w "$FW_TIMEOUT" -nL 2>/dev/null || true)
        if [[ -z "$ipt" ]]; then
            crit "Empty return from $FW_CMD command. Aborting..."
            return
        fi
        for chain in $FW_CHAINS; do
            regex="Chain $chain \(policy ([A-Z]+)\)"
            # previous line will capture actual policy
            if [[ "$ipt" =~ $regex ]]; then
                actual_policy=${BASH_REMATCH[1]}
                if [[ "$actual_policy" = "$FW_POLICY" ]]; then
                    ok "Policy correctly set to $FW_POLICY for chain $chain"
                else
                    crit "Policy set to $actual_policy for chain $chain, should be ${FW_POLICY}."
                fi
            else
                echo "cant find chain $chain"
            fi
        done
    fi
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
if [ -z "$CIS_ROOT_DIR" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_ROOT_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r "$CIS_ROOT_DIR"/lib/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "$CIS_ROOT_DIR"/lib/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_ROOT_DIR in /etc/default/cis-hardening"
    exit 128
fi
