#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 6.3.2.4 Ensure system warns when audit logs are low on space (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure system warns when audit logs are low on space."

AUDITD_CONF_FILE='/etc/audit/auditd.conf'

# Global state
ASLA_SPACE_LEFT_OK=1
ASLA_ADMIN_SPACE_LEFT_OK=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    if [ ! -f "$AUDITD_CONF_FILE" ]; then
        crit "$AUDITD_CONF_FILE does not exist"
        return
    fi

    # Check space_left_action
    local space_left_action
    space_left_action=$(grep -P -- '^\h*space_left_action\h*=\h*\S+' "$AUDITD_CONF_FILE" | awk -F= '{print $2}' | tr -d ' ' || true)

    if echo "$space_left_action" | grep -qE '^(email|exec|single|halt)$'; then
        ok "space_left_action is set to $space_left_action"
        ASLA_SPACE_LEFT_OK=0
    else
        crit "space_left_action is set to '$space_left_action' instead of email, exec, single, or halt"
        ASLA_SPACE_LEFT_OK=1
    fi

    # Check admin_space_left_action
    local admin_space_left_action
    admin_space_left_action=$(grep -P -- '^\h*admin_space_left_action\h*=\h*\S+' "$AUDITD_CONF_FILE" | awk -F= '{print $2}' | tr -d ' ' || true)

    if echo "$admin_space_left_action" | grep -qE '^(single|halt)$'; then
        ok "admin_space_left_action is set to $admin_space_left_action"
        ASLA_ADMIN_SPACE_LEFT_OK=0
    else
        crit "admin_space_left_action is set to '$admin_space_left_action' instead of single or halt"
        ASLA_ADMIN_SPACE_LEFT_OK=1
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ ! -f "$AUDITD_CONF_FILE" ]; then
        crit "$AUDITD_CONF_FILE does not exist, cannot apply"
        return
    fi

    # Fix space_left_action
    if [ "$ASLA_SPACE_LEFT_OK" -ne 0 ]; then
        info "Setting space_left_action to email"
        backup_file "$AUDITD_CONF_FILE"
        # Remove any existing space_left_action lines
        sed -i '/^\s*space_left_action\s*=/d' "$AUDITD_CONF_FILE"
        # Add the correct setting
        echo "space_left_action = email" >>"$AUDITD_CONF_FILE"
    else
        ok "space_left_action is already correctly configured"
    fi

    # Fix admin_space_left_action
    if [ "$ASLA_ADMIN_SPACE_LEFT_OK" -ne 0 ]; then
        info "Setting admin_space_left_action to single"
        backup_file "$AUDITD_CONF_FILE"
        # Remove any existing admin_space_left_action lines
        sed -i '/^\s*admin_space_left_action\s*=/d' "$AUDITD_CONF_FILE"
        # Add the correct setting
        echo "admin_space_left_action = single" >>"$AUDITD_CONF_FILE"
    else
        ok "admin_space_left_action is already correctly configured"
    fi

    # Restart auditd if changes were made
    if [ "$ASLA_SPACE_LEFT_OK" -ne 0 ] || [ "$ASLA_ADMIN_SPACE_LEFT_OK" -ne 0 ]; then
        info "Restarting auditd to apply changes"
        service auditd restart || true
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
