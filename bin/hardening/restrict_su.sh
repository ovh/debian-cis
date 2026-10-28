#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure access to the su command is restricted (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Restrict access to su command."

PACKAGE='login'
FILE='/etc/pam.d/su'
SU_WHEEL_GROUP=''
RESTRICT_SU_NEEDS_REMEDIATION=1
RESTRICT_SU_PATTERN=''
RESTRICT_SU_LINE=''

build_restrict_su_rule() {
    if [ -n "$SU_WHEEL_GROUP" ]; then
        RESTRICT_SU_PATTERN='^auth[[:space:]]*required[[:space:]]*pam_wheel\.so[[:space:]]+use_uid[[:space:]]+group='
        RESTRICT_SU_PATTERN="$RESTRICT_SU_PATTERN$SU_WHEEL_GROUP"
        RESTRICT_SU_PATTERN="$RESTRICT_SU_PATTERN$"
        RESTRICT_SU_LINE="auth       required   pam_wheel.so use_uid group=$SU_WHEEL_GROUP"
    else
        RESTRICT_SU_PATTERN='^auth[[:space:]]*required[[:space:]]*pam_wheel\.so$'
        RESTRICT_SU_LINE='auth       required   pam_wheel.so'
    fi
}

# This function will be called if the script status is on enabled / audit mode
audit() {
    build_restrict_su_rule
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        ok "$PACKAGE is not installed, not applicable"
        RESTRICT_SU_NEEDS_REMEDIATION=0
        return
    fi

    ok "$PACKAGE is installed"

    does_pattern_exist_in_file "$FILE" "$RESTRICT_SU_PATTERN"
    if [ "$FNRET" = 0 ]; then
        ok "$RESTRICT_SU_PATTERN is present in $FILE"
        RESTRICT_SU_NEEDS_REMEDIATION=0
    else
        crit "$RESTRICT_SU_PATTERN is not present in $FILE"
        RESTRICT_SU_NEEDS_REMEDIATION=1
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    build_restrict_su_rule
    local ACTIVE_PAM_WHEEL_PATTERN='^[[:space:]]*auth[[:space:]]*required[[:space:]]*pam_wheel\.so([[:space:]]+.*)?$'
    local COMMENTED_PAM_WHEEL_PATTERN='^[[:space:]]*#[[:space:]]*auth[[:space:]]*required[[:space:]]*pam_wheel\.so([[:space:]]+.*)?$'

    if [ "$RESTRICT_SU_NEEDS_REMEDIATION" = 0 ]; then
        ok "$RESTRICT_SU_PATTERN is already present in $FILE or package is not installed"
        return
    fi

    if does_pattern_exist_in_file "$FILE" "$ACTIVE_PAM_WHEEL_PATTERN"; then
        info "Parameter pam_wheel.so is present but not fully compliant -- Fixing"
        sed -i -E "/$ACTIVE_PAM_WHEEL_PATTERN/d" "$FILE"
    fi

    if does_pattern_exist_in_file "$FILE" "$COMMENTED_PAM_WHEEL_PATTERN"; then
        info "Uncommenting pam_wheel.so template -- Fixing"
        sed -i -E "/$COMMENTED_PAM_WHEEL_PATTERN/d" "$FILE"
    fi

    if does_pattern_exist_in_file "$FILE" '^[[:space:]]*@include[[:space:]]*common-auth$'; then
        add_line_file_before_pattern "$FILE" "$RESTRICT_SU_LINE" '^[[:space:]]*@include[[:space:]]*common-auth$'
    else
        add_end_of_file "$FILE" "$RESTRICT_SU_LINE"
    fi
}

# This function will check config parameters required
check_config() {
    :
}

create_config() {
    cat <<EOF
status=audit
# Optional group allowed to use su with pam_wheel.so (leave empty to disable group restriction)
SU_WHEEL_GROUP=''
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
