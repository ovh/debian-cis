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
DESCRIPTION="Ensure local login warning banner is configured properly (no OS/version information)"

# Global variables with unique prefix
ISSUE_NO_OS_INFO_FILE="/etc/issue"
ISSUE_NO_OS_INFO_PATTERN='\\v|\\r|\\m|\\s'
# Global variables to store audit state
ISSUE_NO_OS_INFO_FILE_EXISTS=1
ISSUE_NO_OS_INFO_PATTERN_FOUND=1

audit() {
    does_file_exist "$ISSUE_NO_OS_INFO_FILE"
    ISSUE_NO_OS_INFO_FILE_EXISTS=$FNRET
    if [ "$ISSUE_NO_OS_INFO_FILE_EXISTS" -ne 0 ]; then
        crit "$ISSUE_NO_OS_INFO_FILE does not exist"
        return
    fi

    does_pattern_exist_in_file "$ISSUE_NO_OS_INFO_FILE" "$ISSUE_NO_OS_INFO_PATTERN"
    ISSUE_NO_OS_INFO_PATTERN_FOUND=$FNRET
    if [ "$ISSUE_NO_OS_INFO_PATTERN_FOUND" -eq 0 ]; then
        crit "$ISSUE_NO_OS_INFO_FILE contains OS information escape sequences"
    else
        ok "$ISSUE_NO_OS_INFO_FILE does not contain OS information"
    fi
}

apply() {
    if [ "$ISSUE_NO_OS_INFO_FILE_EXISTS" -ne 0 ]; then
        info "Creating $ISSUE_NO_OS_INFO_FILE"
        touch "$ISSUE_NO_OS_INFO_FILE"
        ok "$ISSUE_NO_OS_INFO_FILE created"
        return
    fi

    if [ "$ISSUE_NO_OS_INFO_PATTERN_FOUND" -eq 0 ]; then
        info "Removing OS information from $ISSUE_NO_OS_INFO_FILE"
        backup_file "$ISSUE_NO_OS_INFO_FILE"
        sed -i 's/\\v//g; s/\\r//g; s/\\m//g; s/\\s//g' "$ISSUE_NO_OS_INFO_FILE"
        ok "$ISSUE_NO_OS_INFO_FILE OS information removed"
    else
        ok "$ISSUE_NO_OS_INFO_FILE does not contain OS information"
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
