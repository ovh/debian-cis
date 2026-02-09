#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure sudo log file is audited (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=4
# shellcheck disable=2034
DESCRIPTION="Ensure audit rules for sudo log file are configured."

AUDIT_RULES_FILE='/etc/audit/rules.d/50-sudo.rules'

# Global state
RULES_OK=1
SUDO_LOG_FILE=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    RULES_OK=1

    # Find sudo log file from sudoers configuration
    SUDO_LOG_FILE=$(grep -roP "^Defaults\s+logfile=\K[^,\s]+" /etc/sudoers /etc/sudoers.d/ 2>/dev/null | head -n1 | cut -d: -f2)

    if [ -z "$SUDO_LOG_FILE" ]; then
        warn "No sudo logfile configured in sudoers, skipping audit rule check"
        return
    fi

    if [ ! -f "$AUDIT_RULES_FILE" ]; then
        crit "Audit rules file $AUDIT_RULES_FILE does not exist"
        RULES_OK=0
        return
    fi

    # Check if the sudo log file is being audited
    if ! grep -q "$SUDO_LOG_FILE" "$AUDIT_RULES_FILE"; then
        crit "Sudo log file $SUDO_LOG_FILE is not audited"
        RULES_OK=0
    else
        ok "Sudo log file $SUDO_LOG_FILE is audited"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ -z "$SUDO_LOG_FILE" ]; then
        warn "No sudo logfile configured in sudoers, cannot create audit rule"
        return
    fi

    if [ "$RULES_OK" -eq 0 ]; then
        info "Creating sudo log audit rules for $SUDO_LOG_FILE"
        mkdir -p "$(dirname "$AUDIT_RULES_FILE")"

        cat >"$AUDIT_RULES_FILE" <<EOF
## Sudo log file
-w $SUDO_LOG_FILE -p wa -k sudo_log_file
EOF

        # Load the rules
        info "Loading audit rules"
        augenrules --load || true
    else
        ok "Sudo log audit rules already configured"
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
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is ${CIS_LIB_DIR} in /etc/default/cis-hardening"
    exit 128
fi
