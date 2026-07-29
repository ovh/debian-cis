#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

set -e
set -u

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Ensure message of the day is configured properly (no OS/version information)"

# Global variables with unique prefix
MOTD_NO_OS_INFO_FILE="/etc/motd"
MOTD_NO_OS_INFO_PATTERN='\\v|\\r|\\m|\\s'
# Global variables to store audit state
MOTD_NO_OS_INFO_FILE_EXISTS=1
MOTD_NO_OS_INFO_PATTERN_FOUND=1

audit() {
    does_file_exist "$MOTD_NO_OS_INFO_FILE"
    MOTD_NO_OS_INFO_FILE_EXISTS=$FNRET
    if [ "$MOTD_NO_OS_INFO_FILE_EXISTS" -ne 0 ]; then
        ok "$MOTD_NO_OS_INFO_FILE does not exist"
        return
    fi

    does_pattern_exist_in_file "$MOTD_NO_OS_INFO_FILE" "$MOTD_NO_OS_INFO_PATTERN"
    MOTD_NO_OS_INFO_PATTERN_FOUND=$FNRET
    if [ "$MOTD_NO_OS_INFO_PATTERN_FOUND" -eq 0 ]; then
        crit "$MOTD_NO_OS_INFO_FILE contains OS information escape sequences"
    else
        ok "$MOTD_NO_OS_INFO_FILE does not contain OS information"
    fi
}

apply() {
    if [ "$MOTD_NO_OS_INFO_FILE_EXISTS" -ne 0 ]; then
        ok "$MOTD_NO_OS_INFO_FILE does not exist (nothing to apply)"
        return
    fi

    if [ "$MOTD_NO_OS_INFO_PATTERN_FOUND" -eq 0 ]; then
        info "Removing OS information from $MOTD_NO_OS_INFO_FILE"
        backup_file "$MOTD_NO_OS_INFO_FILE"
        sed -i 's/\\v//g; s/\\r//g; s/\\m//g; s/\\s//g' "$MOTD_NO_OS_INFO_FILE"
        ok "$MOTD_NO_OS_INFO_FILE OS information removed"
    else
        ok "$MOTD_NO_OS_INFO_FILE does not contain OS information"
    fi
}

check_config() {
    :
}

# Source Root Dir Parameter
if [ -r /etc/default/cis-hardening ]; then
    # shellcheck source=../../debian/default
    . /etc/default/cis-hardening
fi

if [ -z "${CIS_LIB_DIR:-}" ]; then
    echo "There is no /etc/default/cis-hardening file nor CIS_LIB_DIR in environment."
    exit 128
fi

# Main function
if [ -r "${CIS_LIB_DIR}/main.sh" ]; then
    # shellcheck source=../../lib/main.sh
    . "${CIS_LIB_DIR}/main.sh"
else
    echo "Cannot find main.sh in CIS_LIB_DIR=${CIS_LIB_DIR}"
    exit 128
fi
