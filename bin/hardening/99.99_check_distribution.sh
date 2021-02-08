#!/bin/bash

# run-shellcheck
#
# OVH Security audit
#

#
# 99.99 Ensure that the distribution version is debian and that the version is 9 or 10
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Check the distribution and the distribution version"

# This function will be called if the script status is on enabled / audit mode
audit() {
    if [ "$DISTRIBUTION" != "debian" ]; then
        crit "Your distribution has been identified as $DISTRIBUTION which is not debian"
    else
        if [ "$DEB_MAJ_VER" = "sid" ] || [ "$DEB_MAJ_VER" -gt "$HIGHEST_SUPPORTED_DEBIAN_VERSION" ]; then
            crit "Your distribution is too recent and is not yet supported."
        elif [ "$DEB_MAJ_VER" -lt "$SMALLEST_SUPPORTED_DEBIAN_VERSION" ]; then
            crit "Your distribution is debian but is deprecated. Consider upgrading to a supported version."
        else
            ok "Your distribution is debian and the version is supported"

        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    echo "Reporting only here, upgrade your debian version to a supported version if you're on debian"
    echo "If you use another distribution, consider applying rules corresponding with your distribution available at https://www.cisecurity.org/"
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
