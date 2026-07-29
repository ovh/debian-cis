#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure the running and on disk configuration is the same (Manual)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure the running and on disk configuration is the same"

# This function will be called if the script status is on enabled / audit mode
# shellcheck disable=2120
audit() {
    # Ensure that all rules in /etc/audit/rules.d have been merged into /etc/audit/audit.rules
    AUDIT_RULES_UPTODATE=0
    BINARY_PATH="/usr/sbin"

    # the day we clean debian 11, don't forget the sudo rules
    if [ "$DEB_MAJ_VER" -eq 11 ]; then
        BINARY_PATH="/sbin"
    fi

    local result
    result=$($SUDO_CMD "$BINARY_PATH"/augenrules --check)
    # /usr/sbin/augenrules: No change
    # or
    # /usr/sbin/augenrules: Rules have changed and should be updated
    if grep -q "updated" <<<"$result"; then
        AUDIT_RULES_UPTODATE=1
    fi

    if [ "$AUDIT_RULES_UPTODATE" -eq 0 ]; then
        ok "audit rules are merged"
    else
        crit "audit rules need to be merged"
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$AUDIT_RULES_UPTODATE" -eq 1 ]; then
        info "merging audit rules"
        "$BINARY_PATH"/augenrules --load
    fi

    info "check if reboot is required"
    local reboot_required=0
    reboot_required=$($SUDO_CMD "$BINARY_PATH"/auditctl -s | awk '/enabled/ {print  $2}')
    if [ "$reboot_required" -eq 2 ]; then
        info "Reboot required to load rules"
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
