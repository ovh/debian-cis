#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure root is the only GID 0 account (Automated)
#

set -e
set -u

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Ensure root is the only GID 0 account"

ROG0_NONROOT_USERS=''
ROG0_ROOT_GID_OK=1
ROG0_ONLY_ROOT_OK=1

audit() {
    local root_gid
    root_gid=$(awk -F: '$1=="root" {print $4; exit}' /etc/passwd)
    if [ "$root_gid" = "0" ]; then
        ok "root primary GID is 0"
        ROG0_ROOT_GID_OK=0
    else
        crit "root primary GID is ${root_gid:-missing}, expected 0"
        ROG0_ROOT_GID_OK=1
    fi

    local nonroot_gid0
    nonroot_gid0=$(awk -F: '($1 !~ /^(root|sync|shutdown|halt|operator)$/ && $4=="0") {print $1}' /etc/passwd || true)
    ROG0_NONROOT_USERS="$nonroot_gid0"

    if [ -z "$ROG0_NONROOT_USERS" ]; then
        ok "No non-root account has primary GID 0"
        ROG0_ONLY_ROOT_OK=0
    else
        crit "The following non-root accounts have primary GID 0: $ROG0_NONROOT_USERS"
        ROG0_ONLY_ROOT_OK=1
    fi
}

apply() {
    if [ "$ROG0_ROOT_GID_OK" -ne 0 ]; then
        info "Setting root primary GID to 0"
        usermod -g 0 root
    fi

    if [ "$ROG0_ONLY_ROOT_OK" -ne 0 ]; then
        for l_user in $ROG0_NONROOT_USERS; do
            crit "User '$l_user' has primary GID 0. Manual remediation required to set a non-zero GID."
        done
    fi
}

check_config() {
    :
}

if [ -r /etc/default/cis-hardening ]; then
    # shellcheck source=../../debian/default
    . /etc/default/cis-hardening
fi
if [ -z "${CIS_LIB_DIR}" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_LIB_DIR variable, aborting."
    exit 128
fi

if [ -r "${CIS_LIB_DIR}"/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "${CIS_LIB_DIR}"/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is ${CIS_LIB_DIR} in /etc/default/cis-hardening"
    exit 128
fi
