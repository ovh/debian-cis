#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure all groups in /etc/passwd exist in /etc/group (Manual)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Ensure all groups in /etc/passwd exist in /etc/group"

# This function will be called if the script status is on enabled / audit mode
audit() {
    local invalid_group_gid=""
    local passwd_group_gid=""
    local group_gid=""

    # straight from the debian CIS pdf, works fine as is
    passwd_group_gid=("$(awk -F: '{print $4}' /etc/passwd | sort -u)")
    group_gid=("$(awk -F: '{print $3}' /etc/group | sort -u)")
    passwd_group_diff=("$(printf '%s\n' "${group_gid[@]}" "${passwd_group_gid[@]}" | sort | uniq -u)")

    while IFS= read -r l_gid; do
        invalid_group_gid=$(awk -F: '($4 == '"$l_gid"') {print $4}' /etc/passwd)
        if [ -n "$invalid_group_gid" ]; then
            crit "group with gid $invalid_group_gid is present in /etc/passwd but absent from /etc/group"
        fi
    done < <(printf '%s\n' "${passwd_group_gid[@]}" "${passwd_group_diff[@]}" | sort | uniq -D | uniq)

}

# This function will be called if the script status is on enabled mode
apply() {
    # the CIS recommendation is to do it in an automated way, while also "Investigate to determine if the account is logged in and what it is being used for, to
    # determine if it needs to be forced off"
    # so we do this manually
    info "Please review the faulty accounts and update their password configuration, or set them as exceptions in the configuration"
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
