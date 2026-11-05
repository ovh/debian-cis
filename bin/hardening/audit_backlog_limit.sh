#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure audit_backlog_limit is sufficient (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=4
# shellcheck disable=2034
DESCRIPTION="Configure audit_backlog_limit to be sufficient."

AUDIT_BACKLOG_LIMIT_FILE='/etc/default/grub'
AUDIT_BACKLOG_LIMIT_PARAM='GRUB_CMDLINE_LINUX'
# match the value of every audit_backlog_limit kernel parameter on a line
AUDIT_BACKLOG_LIMIT_PATTERN="(?<![^\\s\"'=])audit_backlog_limit=\\K[^\\s\"']*"

# User-configurable: minimal accepted value, filled by check_config() if empty
AUDIT_BACKLOG_LIMIT_MIN=""

# 0 = true / success, 1 = false / failure
AUDIT_BACKLOG_LIMIT_FILE_EXISTS=1
AUDIT_BACKLOG_LIMIT_PARAM_EXISTS=1
AUDIT_BACKLOG_LIMIT_OK=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    local l_line l_var l_value
    local l_found=1
    local l_invalid=1

    does_file_exist "$AUDIT_BACKLOG_LIMIT_FILE"
    if [ "$FNRET" != 0 ]; then
        crit "$AUDIT_BACKLOG_LIMIT_FILE does not exist"
        return
    fi
    AUDIT_BACKLOG_LIMIT_FILE_EXISTS=0

    does_pattern_exist_in_file "$AUDIT_BACKLOG_LIMIT_FILE" "^\s*${AUDIT_BACKLOG_LIMIT_PARAM}="
    if [ "$FNRET" = 0 ]; then
        AUDIT_BACKLOG_LIMIT_PARAM_EXISTS=0
    fi

    # GRUB_CMDLINE_LINUX_DEFAULT is appended after GRUB_CMDLINE_LINUX on the kernel command line,
    # so every occurrence in both variables must be sufficient
    while IFS= read -r l_line; do
        l_var=$(sed -E 's/^\s*([A-Z_]+)=.*/\1/' <<<"$l_line")
        while IFS= read -r l_value; do
            if [[ ! "$l_value" =~ ^[0-9]+$ ]] || [ "$l_value" -lt "$AUDIT_BACKLOG_LIMIT_MIN" ]; then
                crit "audit_backlog_limit=$l_value in $l_var is lower than $AUDIT_BACKLOG_LIMIT_MIN or invalid"
                l_invalid=0
            else
                l_found=0
            fi
        done < <(grep -oP -- "$AUDIT_BACKLOG_LIMIT_PATTERN" <<<"$l_line" || true)
    done < <($SUDO_CMD grep -E -- '^\s*GRUB_CMDLINE_LINUX(_DEFAULT)?=' "$AUDIT_BACKLOG_LIMIT_FILE" || true)

    if [ "$l_found" != 0 ]; then
        crit "audit_backlog_limit is not set to $AUDIT_BACKLOG_LIMIT_MIN or more in GRUB_CMDLINE_LINUX or GRUB_CMDLINE_LINUX_DEFAULT in $AUDIT_BACKLOG_LIMIT_FILE"
    elif [ "$l_invalid" != 0 ]; then
        ok "audit_backlog_limit is set to $AUDIT_BACKLOG_LIMIT_MIN or more in $AUDIT_BACKLOG_LIMIT_FILE"
        AUDIT_BACKLOG_LIMIT_OK=0
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$AUDIT_BACKLOG_LIMIT_OK" = 0 ]; then
        ok "audit_backlog_limit is already correctly configured"
        return
    fi

    if [ "$AUDIT_BACKLOG_LIMIT_FILE_EXISTS" != 0 ]; then
        warn "$AUDIT_BACKLOG_LIMIT_FILE does not exist, cannot configure audit_backlog_limit"
        return
    fi

    backup_file "$AUDIT_BACKLOG_LIMIT_FILE"
    info "Removing existing audit_backlog_limit values from $AUDIT_BACKLOG_LIMIT_FILE"
    sed -i -E "/^\s*GRUB_CMDLINE_LINUX(_DEFAULT)?=/ s/\s*\baudit_backlog_limit=[^[:space:]\"']*//g" "$AUDIT_BACKLOG_LIMIT_FILE"

    if [ "$AUDIT_BACKLOG_LIMIT_PARAM_EXISTS" = 0 ]; then
        info "Adding audit_backlog_limit=$AUDIT_BACKLOG_LIMIT_MIN to $AUDIT_BACKLOG_LIMIT_PARAM in $AUDIT_BACKLOG_LIMIT_FILE"
        # first expression handles quoted values, second one unquoted (or empty) values
        sed -i -E \
            -e "s/^(\s*${AUDIT_BACKLOG_LIMIT_PARAM}=)([\"'])/\1\2audit_backlog_limit=${AUDIT_BACKLOG_LIMIT_MIN} /" \
            -e "s/^(\s*${AUDIT_BACKLOG_LIMIT_PARAM}=)([^\"']*)$/\1\"audit_backlog_limit=${AUDIT_BACKLOG_LIMIT_MIN} \2\"/" \
            "$AUDIT_BACKLOG_LIMIT_FILE"
    else
        info "$AUDIT_BACKLOG_LIMIT_PARAM is absent from $AUDIT_BACKLOG_LIMIT_FILE, adding it at the end"
        add_end_of_file "$AUDIT_BACKLOG_LIMIT_FILE" "${AUDIT_BACKLOG_LIMIT_PARAM}=\"audit_backlog_limit=${AUDIT_BACKLOG_LIMIT_MIN}\""
    fi

    if command -v update-grub >/dev/null 2>&1; then
        info "Updating grub configuration"
        if ! update-grub; then
            warn "update-grub failed, grub configuration must be regenerated manually"
        fi
    else
        warn "update-grub not found, grub configuration must be regenerated manually"
    fi
}

create_config() {
    cat <<EOF
status=audit
# Minimal accepted value for the audit_backlog_limit kernel parameter (8192 or more)
AUDIT_BACKLOG_LIMIT_MIN=8192
EOF
}

# This function will check config parameters required
check_config() {
    if [ -z "$AUDIT_BACKLOG_LIMIT_MIN" ]; then
        AUDIT_BACKLOG_LIMIT_MIN=8192
    fi
    if [[ ! "$AUDIT_BACKLOG_LIMIT_MIN" =~ ^[0-9]+$ ]]; then
        crit "AUDIT_BACKLOG_LIMIT_MIN must be a positive integer, got '$AUDIT_BACKLOG_LIMIT_MIN'"
        exit 128
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
