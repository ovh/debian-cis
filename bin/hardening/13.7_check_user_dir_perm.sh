#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 13.7 Check Permissions on User Home Directories (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

ERRORS=0

# This function will be called if the script status is on enabled / audit mode
audit () {
    for dir in $(cat /etc/passwd | /bin/egrep -v '(root|halt|sync|shutdown)' | awk -F: '($7 != "/usr/sbin/nologin" && $7 != "/bin/false" && $7 !="/nonexistent" ) { print $6 }'); do
        debug "Working on $dir"
        debug "Exceptions : $EXCEPTIONS"
        debug "echo \"$EXCEPTIONS\" | grep -q $dir"
        if echo "$EXCEPTIONS" | grep -q $dir; then
            debug "$dir is confirmed as an exception"
            RESULT=$(sed "s!$dir!!" <<< "$RESULT")
        else
            debug "$dir not found in exceptions"
        fi
        if [ -d $dir ]; then
            dirperm=$(/bin/ls -ld $dir | cut -f1 -d" ")
            if [ $(echo $dirperm | cut -c6 ) != "-" ]; then
                crit "Group Write permission set on directory $dir"
                ERRORS=$((ERRORS+1))
            fi
            if [ $(echo $dirperm | cut -c8 ) != "-" ]; then
                crit "Other Read permission set on directory $dir"
                ERRORS=$((ERRORS+1))
            fi
            if [ $(echo $dirperm | cut -c9 ) != "-" ]; then
                crit "Other Write permission set on directory $dir"
                ERRORS=$((ERRORS+1))
            fi
            if [ $(echo $dirperm | cut -c10 ) != "-" ]; then
                crit "Other Execute permission set on directory $dir"
                ERRORS=$((ERRORS+1))
            fi
        fi
    done

    if [ $ERRORS = 0 ]; then
        ok "No incorrect permissions on home directories"
    fi

}

# This function will be called if the script status is on enabled mode
apply () {
    for dir in $(cat /etc/passwd | /bin/egrep -v '(root|halt|sync|shutdown)' | awk -F: '($7 != "/usr/sbin/nologin" && $7 != "/bin/false" && $7 !="/nonexistent" ) { print $6 }'); do
        debug "Working on $dir"
        debug "Exceptions : $EXCEPTIONS"
        debug "echo \"$EXCEPTIONS\" | grep -q $dir"
        if echo "$EXCEPTIONS" | grep -q $dir; then
            debug "$dir is confirmed as an exception"
            RESULT=$(sed "s!$dir!!" <<< "$RESULT")
        else
            debug "$dir not found in exceptions"
        fi
        if [ -d $dir ]; then
            dirperm=$(/bin/ls -ld $dir | cut -f1 -d" ")
            if [ $(echo $dirperm | cut -c6 ) != "-" ]; then
                warn "Group Write permission set on directory $dir"
                chmod g-w $dir
            fi
            if [ $(echo $dirperm | cut -c8 ) != "-" ]; then
                warn "Other Read permission set on directory $dir"
                chmod o-r $dir
            fi
            if [ $(echo $dirperm | cut -c9 ) != "-" ]; then
                warn "Other Write permission set on directory $dir"
                chmod o-w $dir
            fi
            if [ $(echo $dirperm | cut -c10 ) != "-" ]; then
                warn "Other Execute permission set on directory $dir"   
                chmod o-x $dir
            fi
        fi
    done
}

# This function will check config parameters required
check_config() {
    if [ -z "$EXCEPTIONS" ]; then
        EXCEPTIONS="@"
    fi
}

# Source Root Dir Parameter
if [ ! -r /etc/default/cis-hardening ]; then
    echo "There is no /etc/default/cis-hardening file, cannot source CIS_ROOT_DIR variable, aborting"
    exit 128
else
    . /etc/default/cis-hardening
    if [ -z $CIS_ROOT_DIR ]; then
        echo "No CIS_ROOT_DIR variable, aborting"
    fi
fi 

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
[ -r $CIS_ROOT_DIR/lib/main.sh ] && . $CIS_ROOT_DIR/lib/main.sh
