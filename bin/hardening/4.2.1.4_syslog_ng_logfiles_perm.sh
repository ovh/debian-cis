#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 4.2.1.4 Create and Set Permissions on syslog-ng Log Files (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Create and set permissions on syslog-ng logfiles."

# Note: this is not exacly the same check as the one described in CIS PDF

PACKAGE='syslog-ng'
PERMISSIONS=''
USER=''
GROUP=''
EXCEPTIONS=''

# This function will be called if the script status is on enabled / audit mode
audit() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        crit "$PACKAGE is not installed!"
    else
        FILES=$(grep "file(" "$SYSLOG_BASEDIR"/syslog-ng.conf | grep '"' | cut -d'"' -f 2)
        for FILE in $FILES; do
            does_file_exist "$FILE"
            if [ "$FNRET" != 0 ]; then
                warn "$FILE does not exist"
            else
                FOUND_EXC=0
                if grep -q "$FILE" <(tr ' ' '\n' <<<"$EXCEPTIONS" | cut -d ":" -f 1); then
                    debug "$FILE is found in exceptions"
                    debug "Setting special user:group:perm"
                    FOUND_EXC=1
                    local user_bak="$USER"
                    local group_bak="$GROUP"
                    local perm_bak="$PERMISSIONS"
                    USER="$(tr ' ' '\n' <<<"$EXCEPTIONS" | grep "$FILE" | cut -d':' -f 2)"
                    GROUP="$(tr ' ' '\n' <<<"$EXCEPTIONS" | grep "$FILE" | cut -d':' -f 3)"
                    PERMISSIONS="$(tr ' ' '\n' <<<"$EXCEPTIONS" | grep "$FILE" | cut -d':' -f 4)"
                fi
                has_file_correct_ownership "$FILE" "$USER" "$GROUP"
                if [ "$FNRET" = 0 ]; then
                    ok "$FILE has correct ownership ($USER:$GROUP)"
                else
                    crit "$FILE ownership was not set to $USER:$GROUP"
                fi
                has_file_correct_permissions "$FILE" "$PERMISSIONS"
                if [ "$FNRET" = 0 ]; then
                    ok "$FILE has correct permissions ($PERMISSIONS)"
                else
                    crit "$FILE permissions were not set to $PERMISSIONS"
                fi
                if [ "$FOUND_EXC" = 1 ]; then
                    debug "Resetting user:group:perm"
                    USER="$user_bak"
                    GROUP="$group_bak"
                    PERMISSIONS="$perm_bak"
                fi
            fi
        done
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        crit "$PACKAGE is not installed!"
    else
        for FILE in $FILES; do
            does_file_exist "$FILE"
            if [ "$FNRET" != 0 ]; then
                info "$FILE does not exist"
                filedir=$(dirname "${FILE#/var/log/}")
                if [ ! "$filedir" = "." ] && [ ! -d /var/log/"$filedir" ]; then
                    debug "Creating /var/log/$filedir for $FILE"
                    debug "mkdir -p /var/log/$filedir"
                    mkdir -p /var/log/"$filedir"
                fi
                touch "$FILE"
            fi
            FOUND_EXC=0
            if grep "$FILE" <(tr ' ' '\n' <<<"$EXCEPTIONS" | cut -d ":" -f 1); then
                debug "$FILE is found in exceptions"
                debug "Setting special user:group:perm"
                FOUND_EXC=1
                local user_bak="$USER"
                local group_bak="$GROUP"
                local perm_bak="$PERMISSIONS"
                USER="$(tr ' ' '\n' <<<"$EXCEPTIONS" | grep "$FILE" | cut -d':' -f 2)"
                GROUP="$(tr ' ' '\n' <<<"$EXCEPTIONS" | grep "$FILE" | cut -d':' -f 3)"
                PERMISSIONS="$(tr ' ' '\n' <<<"$EXCEPTIONS" | grep "$FILE" | cut -d':' -f 4)"
            fi
            has_file_correct_ownership "$FILE" "$USER" "$GROUP"
            if [ "$FNRET" = 0 ]; then
                ok "$FILE has correct ownership"
            else
                warn "fixing $FILE ownership to $USER:$GROUP"
                chown "$USER":"$GROUP" "$FILE"
            fi
            has_file_correct_permissions "$FILE" "$PERMISSIONS"
            if [ "$FNRET" = 0 ]; then
                ok "$FILE has correct permissions"
            else
                info "fixing $FILE permissions to $PERMISSIONS"
                chmod 0"$PERMISSIONS" "$FILE"
            fi
            if [ "$FOUND_EXC" = 1 ]; then
                debug "Resetting user:group:perm"
                USER="$user_bak"
                GROUP="$group_bak"
                PERMISSIONS="$perm_bak"
            fi
        done
    fi
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit
SYSLOG_BASEDIR='/etc/syslog-ng'
PERMISSIONS='640'
USER='root'
GROUP='adm'
# Put exceptions here with file:user:group:permissions
# example: /dev/null:root:root:666
EXCEPTIONS=''
EOF
}

# This function will check config parameters required
check_config() {
    does_user_exist "$USER"
    if [ "$FNRET" != 0 ]; then
        crit "$USER does not exist"
        exit 128
    fi
    does_group_exist "$GROUP"
    if [ "$FNRET" != 0 ]; then
        crit "$GROUP does not exist"
        exit 128
    fi
}

# Source Root Dir Parameter
if [ -r /etc/default/cis-hardening ]; then
    # shellcheck source=../../debian/default
    . /etc/default/cis-hardening
fi
if [ -z "$CIS_ROOT_DIR" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_ROOT_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r "$CIS_ROOT_DIR"/lib/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "$CIS_ROOT_DIR"/lib/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_ROOT_DIR in /etc/default/cis-hardening"
    exit 128
fi
