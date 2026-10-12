#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure no unowned or ungrouped files or directories exist (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure no unowned or ungrouped files or directories exist."

UNOWNED_UNGROUPED_USER='root'
UNOWNED_UNGROUPED_GROUP='root'
IGNORED_PATH=''

# find emits following error if directory or file disappears during
# tree traversal: find: '/tmp/xxx': No such file or directory
FIND_IGNORE_NOSUCHFILE_ERR=false

# Global audit state reused by apply()
UNOWNED_UNGROUPED_UNOWNED_RESULT=''
UNOWNED_UNGROUPED_UNGROUPED_RESULT=''
UNOWNED_UNGROUPED_IS_COMPLIANT=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    local fs_names

    info "Checking if there are unowned or ungrouped files"

    if [ -n "$IGNORED_PATH" ]; then
        # maybe IGNORED_PATH allows us to filter out some FS
        fs_names=$(df --local -P | awk '{if (NR!=1) print $6}' | grep -vE "$IGNORED_PATH")

        [ "$FIND_IGNORE_NOSUCHFILE_ERR" = true ] && set +e
        # shellcheck disable=SC2086
        UNOWNED_UNGROUPED_UNOWNED_RESULT=$($SUDO_CMD find $fs_names -xdev -ignore_readdir_race -nouser -regextype 'egrep' ! -regex "$IGNORED_PATH" -print 2>/dev/null)
        # shellcheck disable=SC2086
        UNOWNED_UNGROUPED_UNGROUPED_RESULT=$($SUDO_CMD find $fs_names -xdev -ignore_readdir_race -nogroup -regextype 'egrep' ! -regex "$IGNORED_PATH" -print 2>/dev/null)
        [ "$FIND_IGNORE_NOSUCHFILE_ERR" = true ] && set -e
    else
        fs_names=$(df --local -P | awk '{if (NR!=1) print $6}')

        [ "$FIND_IGNORE_NOSUCHFILE_ERR" = true ] && set +e
        # shellcheck disable=SC2086
        UNOWNED_UNGROUPED_UNOWNED_RESULT=$($SUDO_CMD find $fs_names -xdev -ignore_readdir_race -nouser -print 2>/dev/null)
        # shellcheck disable=SC2086
        UNOWNED_UNGROUPED_UNGROUPED_RESULT=$($SUDO_CMD find $fs_names -xdev -ignore_readdir_race -nogroup -print 2>/dev/null)
        [ "$FIND_IGNORE_NOSUCHFILE_ERR" = true ] && set -e
    fi

    if [ -z "$UNOWNED_UNGROUPED_UNOWNED_RESULT" ] && [ -z "$UNOWNED_UNGROUPED_UNGROUPED_RESULT" ]; then
        ok "No unowned or ungrouped files found"
        UNOWNED_UNGROUPED_IS_COMPLIANT=0
        return
    fi

    UNOWNED_UNGROUPED_IS_COMPLIANT=1
    crit "Some files are unowned and/or ungrouped are present"

    if [ -n "$UNOWNED_UNGROUPED_UNOWNED_RESULT" ]; then
        crit "Some unowned files are present"
    fi

    if [ -n "$UNOWNED_UNGROUPED_UNGROUPED_RESULT" ]; then
        crit "Some ungrouped files are present"
    fi

    # shellcheck disable=SC2001
    FORMATTED_RESULT=$(printf '%s\n%s\n' "$UNOWNED_UNGROUPED_UNOWNED_RESULT" "$UNOWNED_UNGROUPED_UNGROUPED_RESULT" | sed '/^$/d' | sort | uniq | tr '\n' ' ')
    crit "$FORMATTED_RESULT"
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$UNOWNED_UNGROUPED_IS_COMPLIANT" -eq 0 ]; then
        ok "No unowned or ungrouped files found, nothing to apply"
        return
    fi

    if [ -n "$UNOWNED_UNGROUPED_UNOWNED_RESULT" ]; then
        warn "Applying chown on all unowned files in the system"
        printf '%s\n' "$UNOWNED_UNGROUPED_UNOWNED_RESULT" | sed '/^$/d' | xargs chown "$UNOWNED_UNGROUPED_USER"
    fi

    if [ -n "$UNOWNED_UNGROUPED_UNGROUPED_RESULT" ]; then
        warn "Applying chgrp on all ungrouped files in the system"
        printf '%s\n' "$UNOWNED_UNGROUPED_UNGROUPED_RESULT" | sed '/^$/d' | xargs chgrp "$UNOWNED_UNGROUPED_GROUP"
    fi

    ok "Ownership remediation commands have been applied"
}

# This function will check config parameters required
check_config() {
    :
}

create_config() {
    cat <<EOF
# shellcheck disable=2034
status=audit
# Regex of paths to ignore from owner/group checks
IGNORED_PATH=''
# Ignore transient find race errors (No such file)
FIND_IGNORE_NOSUCHFILE_ERR=false
EOF
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
