#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure latest version of pam is installed (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure latest version of pam is installed."
PACKAGE='libpam-runtime'
MIN_VERSION=''

# This function will be called if the script status is on enabled / audit mode
audit() {
    PACKAGE_IS_VERSION=0
    if [ "$DEB_MAJ_VER" -ge 12 ]; then

        version=$(dpkg-query --show --showformat '${Version}' "$PACKAGE")
        if dpkg --compare-versions "$version" ge "$MIN_VERSION"; then
            ok "$PACKAGE is $version"
        else
            crit "$PACKAGE is $version"
            PACKAGE_IS_VERSION=1
        fi

    else
        info "This recommendation requires at least a debian 12 system"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$PACKAGE_IS_VERSION" -eq 1 ]; then
        apt upgrade -y libpam-runtime
    fi
}

create_config() {
    local PACKAGE_VERSION=""
    if [ "$DEB_MAJ_VER" -eq 12 ]; then
        PACKAGE_VERSION="1.5.2-6"
    elif [ "$DEB_MAJ_VER" -eq 13 ]; then
        PACKAGE_VERSION="1.7.0-5"
    fi
    cat <<EOF
status=audit
MIN_VERSION="$PACKAGE_VERSION"
EOF
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
