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

    # 1.5.2-6+deb12u1 -> 1.5.2-6
    version=$(dpkg-query -s "$PACKAGE" | awk '/Version/ {print $2}' | sed 's/+.*$//')
    if [[ "$version" > "$MIN_VERSION" ]] || [[ "$version" == "$MIN_VERSION" ]]; then
        ok "$PACKAGE is $version"
    else
        crit "$PACKAGE is $version"
        PACKAGE_IS_VERSION=1
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$PACKAGE_IS_VERSION" -eq 1 ]; then
        apt upgrade -y libpam-runtime
    fi
}

create_config() {
    if [ "$DEB_MAJ_VER" -eq 12 ]; then
        cat <<EOF
status=audit
MIN_VERSION="1.5.2-6"
EOF
    fi
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
