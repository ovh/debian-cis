#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure journald log file access is configured (Manual)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure journald log file access is configured"

JOURNALD_FOLDER_PERMS=""
JOURNALD_FILE_PERMS=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    # honestly this check is not very useful and will probably always lead to a "crit" state, unless
    # setting a long list of perms acceptable for file, which is not very useful either
    JOURNALD_ACCESS_VALID=0
    # /etc/tmpfiles.d/systemd.conf will override all default settings as defined in /usr/lib/tmpfiles.d/systemd.conf
    local file_to_check="/usr/lib/tmpfiles.d/systemd.conf"
    does_file_exist /etc/tmpfiles.d/systemd.conf
    if [ "$FNRET" -eq 0 ]; then
        file_to_check="/etc/tmpfiles.d/systemd.conf"
    fi

    while read -r line; do
        file_type=$(echo "$line" | awk '{print $1}')
        file_mode=$(echo "$line" | awk '{print $3}')

        if [ "$file_type" == "d" ]; then
            if [ "$file_mode" -ne "$JOURNALD_FOLDER_PERMS" ]; then
                JOURNALD_ACCESS_VALID=1
                break
            fi
        elif [ "$file_mode" -ne "$JOURNALD_FILE_PERMS" ]; then
            JOURNALD_ACCESS_VALID=1
            break
        fi
    done < <($SUDO_CMD grep -v ^# "$file_to_check" | sed '/^$/d')

    if [ "$JOURNALD_ACCESS_VALID" -eq 0 ]; then
        ok "All files in $file_to_check are correctly configured"
    else
        crit "Some files in $file_to_check are not correctly configured"
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$JOURNALD_ACCESS_VALID" -ne 0 ]; then
        info "Please review manually the file according to your site policy"
    fi
}

# This function will check config parameters required
check_config() {
    :
}

create_config() {
    cat <<EOF
# shellcheck disable=2034
status=audit
# Put here the root login boolean for ssh
JOURNALD_FOLDER_PERMS=0750
JOURNALD_FILE_PERMS=0640
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
