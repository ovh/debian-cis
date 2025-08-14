#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure ufw service is enabled (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure ufw service is enabled"
SERVICE="ufw.service"
CREATE_SSH_RULE=""
SSH_RULE="allow proto tcp from any to any port 22"

# This function will be called if the script status is on enabled / audit mode
audit() {
    SERVICE_ENABLED=1
    SERVICE_ACTIVE=1

    is_service_enabled "$SERVICE"
    if [ "$FNRET" -eq 0 ]; then
        ok "$SERVICE is enabled"
        SERVICE_ENABLED=0
    else
        crit "$SERVICE is not enabled"
    fi

    is_service_active "$SERVICE"
    if [ "$FNRET" -eq 0 ]; then
        ok "$SERVICE is active"
        SERVICE_ACTIVE=0
    else
        crit "$SERVICE is not active"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    audit
    if [ "$SERVICE_ENABLED" -ne 0 ]; then
        manage_service unmask "$SERVICE"
        manage_service enable "$SERVICE"
    fi

    if [ "$SERVICE_ACTIVE" -ne 0 ]; then
        # When running ufw enable or starting ufw via its initscript, ufw will flush its chains.
        # This is required so ufw can maintain a consistent state, but it may drop existing
        # connections (eg ssh). ufw does support adding rules before enabling the firewall.
        if [ "$CREATE_SSH_RULE" -eq 0 ]; then
            info "we are going to modify ufw rules to ensure ssh stays allowed"
            ufw "$SSH_RULE"
        fi
        manage_service start "$SERVICE"
    fi

}

create_config() {
    cat <<EOF
status=audit
# Put your custom configuration here
# 0 = create rule (bash value for boolean true)
# 1 = do not create rule (bash value for boolean true)
CREATE_SSH_RULE=0
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
