#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure Mail Transfer Agent is configured for Local-Only Mode (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Configure Mail Transfert Agent for Local-Only Mode."
# shellcheck disable=2034
HARDENING_EXCEPTION=mail
MTA_PORTS=""
MTA_LISTENING_EXTERNAL=1 # false

# This function will be called if the script status is on enabled / audit mode
audit() {
    info "Checking MTA ports opened"
    for port in $MTA_PORTS; do
        RESULT=$($SUDO_CMD ss -nltu | awk -v port="$port" '$5 ~ ":"port"$" {print $5}')
        if [ -z "$RESULT" ]; then
            ok "Nothing listens on port(s) $port"
        elif grep -qE "^127.0.*:$port$" <<<"$RESULT"; then
            ok "MTA is configured to localhost only on port $port"
        else
            crit "MTA listens worldwide on port $port"
            MTA_LISTENING_EXTERNAL=0
        fi
    done
}

# This function will be called if the script status is on enabled mode
apply() {

    if [ "$MTA_LISTENING_EXTERNAL" -eq 0 ]; then
        info "Please update your MTA configuration"
    fi
}

create_config() {
    # we try to put as default all services that should be running according to the CIS recommendation
    cat <<EOF
status=audit
# Put your mail transfert agent ports configuration here, space separated
# ex: MTA_PORTS="25 465 587"
MTA_PORTS="25"
EOF
}

# This function will check config parameters required
check_config() {
    if [ -z "$MTA_PORTS" ]; then
        MTA_PORTS="25"
    fi
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
