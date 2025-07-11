#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure local interactive user home directories are configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Users are assigned valid home directories"

# a home is purposefully owned by another user
# format: <dir>:<user_name>:<owner_name>
# ex: HOME_OWNER_EXCEPTIONS="/usr/sbin:daemon:root"
HOME_OWNER_EXCEPTIONS=""
# space separated list of path, where permissions are different than 0750
HOME_PERM_EXCEPTIONS=""

ERRORS=0

check_home_owner() {
    # user owns home
    local user=$1
    local home=$2
    FNRET=0

    owner=$(stat -L -c "%U" "$home")
    if [ "$owner" != "$user" ]; then
        EXCEP_FOUND=0
        for excep in $HOME_OWNER_EXCEPTIONS; do
            if [ "$home:$user:$owner" = "$excep" ]; then
                ok "The home directory ($home) of user $user is owned by $owner but is part of exceptions ($home:$user:$owner)."
                EXCEP_FOUND=1
                break
            fi
        done
        if [ "$EXCEP_FOUND" -eq 0 ]; then
            crit "The home directory ($home) of user $user is owned by $owner."
            FNRET=1
        fi
    fi
}

check_home_perm() {
    # 750 or more restrictive
    local home=$1
    HOME_PERM_ERRORS=0

    debug "Exceptions : $HOME_PERM_EXCEPTIONS"
    debug "echo \"$HOME_PERM_EXCEPTIONS\" | grep -q $home"
    if echo "$HOME_PERM_EXCEPTIONS" | grep -q "$home"; then
        debug "$home is confirmed as an exception"
        # shellcheck disable=SC2001
        RESULT=$(sed "s!$home!!" <<<"$RESULT")
    else
        debug "$home not found in exceptions"
    fi
    if [ -d "$home" ]; then
        dirperm=$(/bin/ls -ld "$home" | cut -f1 -d" ")
        if [ "$(echo "$dirperm" | cut -c6)" != "-" ]; then
            crit "Group Write permission set on directory $home"
            HOME_PERM_ERRORS=$((HOME_PERM_ERRORS + 1))
        fi
        if [ "$(echo "$dirperm" | cut -c8)" != "-" ]; then
            crit "Other Read permission set on directory $home"
            HOME_PERM_ERRORS=$((HOME_PERM_ERRORS + 1))
        fi
        if [ "$(echo "$dirperm" | cut -c9)" != "-" ]; then
            crit "Other Write permission set on directory $home"
            HOME_PERM_ERRORS=$((HOME_PERM_ERRORS + 1))
        fi
        if [ "$(echo "$dirperm" | cut -c10)" != "-" ]; then
            crit "Other Execute permission set on directory $home"
            HOME_PERM_ERRORS=$((HOME_PERM_ERRORS + 1))
        fi
    fi
}

# This function will be called if the script status is on enabled / audit mode
audit() {
    RESULT=$(get_db passwd | awk -F: '{ print $1 ":" $3 ":" $6 }')
    for LINE in $RESULT; do
        debug "Working on $LINE"
        USER=$(awk -F: '{print $1}' <<<"$LINE")
        USERID=$(awk -F: '{print $2}' <<<"$LINE")
        DIR=$(awk -F: '{print $3}' <<<"$LINE")
        if [ "$USERID" -ge 1000 ]; then
            if [ ! -d "$DIR" ] && [ "$USER" != "nfsnobody" ] && [ "$USER" != "nobody" ] && [ "$DIR" != "/nonexistent" ]; then
                crit "The home directory ($DIR) of user $USER does not exist."
                ERRORS=$((ERRORS + 1))
            fi

            if [ -d "$DIR" ] && [ "$USER" != "nfsnobody" ]; then
                check_home_owner "$USER" "$DIR"
                [ $FNRET -ne 0 ] && ERRORS=$((ERRORS + 1))
            fi
        fi

    done

    for DIR in $(get_db passwd | grep -Ev '(root|halt|sync|shutdown)' | awk -F: '($7 != "/usr/sbin/nologin" && $7 != "/sbin/nologin" && $7 != "/bin/false" && $7 !="/nonexistent" ) { print $6 }'); do
        check_home_perm "$DIR"
        ERRORS=$((ERRORS + HOME_PERM_ERRORS))
    done

    if [ "$ERRORS" -eq 0 ]; then
        ok "All home directories are correctly configured"
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    info "Modifying home directories may seriously harm your system, report only here"
}

create_config() {
    cat <<EOF
status=audit
# Put here user home directories exceptions
# format: <dir>:<user_name>:<owner_name>
HOME_OWNER_EXCEPTIONS=""
# space separated list of path, where permissions are different than 0750
HOME_PERM_EXCEPTIONS=""
EOF
}

# This function will check config parameters required
check_config() {
    if [ -z "$HOME_PERM_EXCEPTIONS" ]; then
        HOME_PERM_EXCEPTIONS="@"
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
