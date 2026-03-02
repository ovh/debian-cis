#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 5.4.2.3 Ensure group root is the only GID 0 group (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Ensure group root is the only GID 0 group."

# Global state
CRG_OTHER_GID0_GROUPS=""
CRG_ONLY_ROOT_GID0=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    # Find all groups with GID 0 that are not 'root'
    local other_gid0
    other_gid0=$(awk -F: '$3=="0" && $1!="root" {print $1}' /etc/group || true)

    CRG_OTHER_GID0_GROUPS="$other_gid0"

    if [ -z "$CRG_OTHER_GID0_GROUPS" ]; then
        ok "Only root group has GID 0"
        CRG_ONLY_ROOT_GID0=0
    else
        crit "The following groups other than root have GID 0: $CRG_OTHER_GID0_GROUPS"
        CRG_ONLY_ROOT_GID0=1
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$CRG_ONLY_ROOT_GID0" -eq 0 ]; then
        ok "Only root group has GID 0"
        return
    fi

    # For each group with GID 0 that's not root, we need manual intervention
    for group in $CRG_OTHER_GID0_GROUPS; do
        crit "Group '$group' has GID 0. Manual intervention required:"
        crit "  - Either delete the group: groupdel $group"
        crit "  - Or assign a new GID: groupmod -g <NEW_GID> $group"
    done

    crit "This script cannot automatically fix this issue as it requires manual decision"
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
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_LIB_DIR in /etc/default/cis-hardening"
    exit 128
fi
