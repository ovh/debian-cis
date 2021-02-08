#!/bin/bash

# run-shellcheck

#
# Legacy CIS Debian Hardening
#

#
# 99.5.2.2 Checking rekey limit for time (6 hours) or volume (512Mio) whichever comes first.
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Checking rekey limit for time (6 hours) or volume (512Mio) whichever comes first."

PACKAGE='openssh-server'
OPTIONS='RekeyLimit=512M\s+6h'
FILE='/etc/ssh/sshd_config'

# This function will be called if the script status is on enabled / audit mode
audit() {
    set +u
    debug "Debian version : $DEB_MAJ_VER "
    if [[ -z "$DEB_MAJ_VER" ]]; then
        set -u
        crit "Cannot get Debian version. Aborting..."
        return
    fi
    if [[ "${DEB_MAJ_VER}" != "sid" ]] && [[ "${DEB_MAJ_VER}" -lt "8" ]]; then
        set -u
        warn "Debian version too old (${DEB_MAJ_VER}), check does not apply, you should disable this check."
        return
    fi
    set -u
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        ok "$PACKAGE is not installed!"
    else
        ok "$PACKAGE is installed"
        for SSH_OPTION in $OPTIONS; do
            SSH_PARAM=$(echo "$SSH_OPTION" | cut -d= -f 1)
            SSH_VALUE=$(echo "$SSH_OPTION" | cut -d= -f 2)
            PATTERN="^${SSH_PARAM}[[:space:]]*$SSH_VALUE"
            does_pattern_exist_in_file_nocase "$FILE" "$PATTERN"
            if [ "$FNRET" = 0 ]; then
                ok "$PATTERN is present in $FILE"
            else
                crit "$PATTERN is not present in $FILE"
            fi
        done
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" = 0 ]; then
        ok "$PACKAGE is installed"
    else
        crit "$PACKAGE is absent, installing it"
        apt_install "$PACKAGE"
    fi
    for SSH_OPTION in $OPTIONS; do
        SSH_PARAM=$(echo "$SSH_OPTION" | cut -d= -f 1)
        SSH_VALUE=$(echo "$SSH_OPTION" | cut -d= -f 2)
        PATTERN="^${SSH_PARAM}[[:space:]]*$SSH_VALUE"
        does_pattern_exist_in_file_nocase "$FILE" "$PATTERN"
        if [ "$FNRET" = 0 ]; then
            ok "$PATTERN is present in $FILE"
        else
            warn "$PATTERN is not present in $FILE, adding it"
            does_pattern_exist_in_file_nocase "$FILE" "^${SSH_PARAM}"
            if [ "$FNRET" != 0 ]; then
                # shellcheck disable=SC2001
                SSH_VALUE=$(sed 's/\\s+/ /' <<<"$SSH_VALUE")
                add_end_of_file "$FILE" "$SSH_PARAM $SSH_VALUE"
            else
                info "Parameter $SSH_PARAM is present but with the wrong value -- Fixing"
                replace_in_file "$FILE" "^${SSH_PARAM}[[:space:]]*.*" "$SSH_PARAM $SSH_VALUE"
            fi
            /etc/init.d/ssh reload >/dev/null 2>&1
        fi
    done

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
