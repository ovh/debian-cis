#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure auditd low space actions are configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure auditd low space actions are configured."

FILE='/etc/audit/auditd.conf'
SPACE_LEFT_ACTION=''
ADMIN_SPACE_LEFT_ACTION=''

# Global state
CONFIG_OK=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    CONFIG_OK=1

    does_file_exist "$FILE"
    if [ "$FNRET" != 0 ]; then
        crit "$FILE does not exist"
        CONFIG_OK=0
        return
    fi

    # Check space_left_action
    if [ -n "$SPACE_LEFT_ACTION" ]; then
        does_pattern_exist_in_file "$FILE" "^space_left_action[[:space:]]*=[[:space:]]*$SPACE_LEFT_ACTION"
        if [ "$FNRET" != 0 ]; then
            crit "space_left_action is not set to $SPACE_LEFT_ACTION in $FILE"
            CONFIG_OK=0
        else
            ok "space_left_action is correctly set to $SPACE_LEFT_ACTION"
        fi
    fi

    # Check admin_space_left_action
    if [ -n "$ADMIN_SPACE_LEFT_ACTION" ]; then
        does_pattern_exist_in_file "$FILE" "^admin_space_left_action[[:space:]]*=[[:space:]]*$ADMIN_SPACE_LEFT_ACTION"
        if [ "$FNRET" != 0 ]; then
            crit "admin_space_left_action is not set to $ADMIN_SPACE_LEFT_ACTION in $FILE"
            CONFIG_OK=0
        else
            ok "admin_space_left_action is correctly set to $ADMIN_SPACE_LEFT_ACTION"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$CONFIG_OK" -eq 0 ]; then
        does_file_exist "$FILE"
        if [ "$FNRET" != 0 ]; then
            warn "$FILE does not exist, creating it"
            touch "$FILE"
        fi

        backup_file "$FILE"

        # Set space_left_action
        if [ -n "$SPACE_LEFT_ACTION" ]; then
            # Remove existing space_left_action lines to avoid duplicates
            delete_line_in_file "$FILE" "^space_left_action"
            add_end_of_file "$FILE" "space_left_action = $SPACE_LEFT_ACTION"
            info "Set space_left_action to $SPACE_LEFT_ACTION"
        fi

        # Set admin_space_left_action
        if [ -n "$ADMIN_SPACE_LEFT_ACTION" ]; then
            # Remove existing admin_space_left_action lines to avoid duplicates
            delete_line_in_file "$FILE" "^admin_space_left_action"
            add_end_of_file "$FILE" "admin_space_left_action = $ADMIN_SPACE_LEFT_ACTION"
            info "Set admin_space_left_action to $ADMIN_SPACE_LEFT_ACTION"
        fi

        # Restart auditd
        info "Restarting auditd service"
        systemctl restart auditd || service auditd restart || true
    else
        ok "Auditd low space actions already correctly configured"
    fi
}

# This function will check config parameters required
check_config() {
    if [ -z "$SPACE_LEFT_ACTION" ] && [ -z "$ADMIN_SPACE_LEFT_ACTION" ]; then
        crit "Neither SPACE_LEFT_ACTION nor ADMIN_SPACE_LEFT_ACTION is configured"
        exit 128
    fi
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
# Configuration for script: $SCRIPT_NAME
# Action to take when disk space is low
SPACE_LEFT_ACTION='email'
# Action to take when admin intervention is required
ADMIN_SPACE_LEFT_ACTION='halt'
EOF
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
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is ${CIS_LIB_DIR} in /etc/default/cis-hardening"
    exit 128
fi
