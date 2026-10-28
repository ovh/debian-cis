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
JOURNALD_ACCESS_VALID=1
JOURNALD_TMPFILES_CONF=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    local l_errors=0
    local l_type l_path l_mode l_masked l_file_mode

    # /etc/tmpfiles.d/systemd.conf will override all default settings as defined in /usr/lib/tmpfiles.d/systemd.conf
    JOURNALD_TMPFILES_CONF="/usr/lib/tmpfiles.d/systemd.conf"
    does_file_exist /etc/tmpfiles.d/systemd.conf
    if [ "$FNRET" -eq 0 ]; then
        JOURNALD_TMPFILES_CONF="/etc/tmpfiles.d/systemd.conf"
    fi

    # tmpfiles.d line format: <type> <path> <mode> <user> <group> <age> <argument>
    while read -r l_type l_path l_mode _; do
        # only the journal paths are in the scope of this check
        case "$l_path" in
        */log/journal | */log/journal/*) ;;
        *) continue ;;
        esac

        # ':' prefix only means "apply on creation"
        # '~' prefix masks the mode with the existing bits
        l_masked=1
        while [[ "$l_mode" =~ ^[:~] ]]; do
            if [ "${l_mode:0:1}" = "~" ]; then
                l_masked=0
            fi
            l_mode=${l_mode:1}
        done
        # '-' (ACL lines, ...) means the mode is not modified
        if ! [[ "$l_mode" =~ ^[0-7]{1,4}$ ]]; then
            continue
        fi

        # journal directories: /{run,var}/log/journal and /{run,var}/log/journal/%m
        if [[ "$l_type" =~ ^[dDevqQ] ]] || [[ "$l_path" =~ ^/(run|var)/log/journal(/%m)?/?$ ]]; then
            # optional site policy, setgid/sticky bits are ignored as they do not grant access
            if [ -n "$JOURNALD_FOLDER_PERMS" ] && ((8#$l_mode & 8#0777 & ~8#$JOURNALD_FOLDER_PERMS)); then
                crit "journal directory $l_path mode $l_mode is more permissive than $JOURNALD_FOLDER_PERMS in $JOURNALD_TMPFILES_CONF"
                l_errors=1
            fi
            # 'Z' is recursive: the mode is also applied to the journal files in the directory
            if ! [[ "$l_type" =~ ^Z ]]; then
                continue
            fi
        fi

        l_file_mode=$((8#$l_mode))
        if [ "$l_masked" -eq 0 ]; then
            # journal files have no executable bit, so '~' removes them, and special bits are only kept on directories
            l_file_mode=$((l_file_mode & 8#0666))
        fi
        if ((l_file_mode & ~8#$JOURNALD_FILE_PERMS)); then
            crit "journal files under $l_path mode $(printf '%04o' "$l_file_mode") is more permissive than $JOURNALD_FILE_PERMS in $JOURNALD_TMPFILES_CONF"
            l_errors=1
        fi
    done < <($SUDO_CMD grep -Ev '^[[:space:]]*(#|$)' "$JOURNALD_TMPFILES_CONF")

    if [ "$l_errors" -eq 0 ]; then
        JOURNALD_ACCESS_VALID=0
        ok "journal files permissions are $JOURNALD_FILE_PERMS or more restrictive in $JOURNALD_TMPFILES_CONF"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$JOURNALD_ACCESS_VALID" -ne 0 ]; then
        info "Copy /usr/lib/tmpfiles.d/systemd.conf to /etc/tmpfiles.d/systemd.conf if needed, and set the journal permissions according to your site policy"
    fi
}

# This function will check config parameters required
check_config() {
    if [ -z "$JOURNALD_FILE_PERMS" ]; then
        JOURNALD_FILE_PERMS=0640
    fi
}

create_config() {
    cat <<EOF
status=audit
# maximum permissions for the journal files (CIS: 0640 or more restrictive)
JOURNALD_FILE_PERMS=0640
# optional site policy: maximum permissions for the journal directories (setgid/sticky bits are ignored)
# empty means directories are not checked, as the CIS recommendation only covers the journal files
JOURNALD_FOLDER_PERMS=""
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
