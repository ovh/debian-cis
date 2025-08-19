#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure systemd-journal-remote authentication is configured (Manual)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure systemd-journal-remote authentication is configured"
JOURNAL_CONF="/etc/systemd/journal-upload.conf"

# This function will be called if the script status is on enabled / audit mode
# shellcheck disable=2120
audit() {
    local conf_lines
    # We are looking for URL, ServerKeyFile, ServerCertificateFile, TrustedCertificateFile
    # shellcheck disable=2126
    conf_lines=$(grep -P "^ *URL=|^ *ServerKeyFile=|^ *ServerCertificateFile=|^ *TrustedCertificateFile=" "$JOURNAL_CONF" | wc -l)
    if [ "$conf_lines" -eq 4 ]; then
        ok "remote authentication is configured, review it manually to ensure it is the expected one"
    else
        crit "remote authentication is not configured. Either configure it, or disable this recommendation if not needed."
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    info "Please review manually your authentication configuration"
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
