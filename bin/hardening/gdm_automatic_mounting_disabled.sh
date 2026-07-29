#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure GDM automatic mounting of removable media is disabled (Automated)
#

set -e
set -u

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Ensure GDM automatic mounting of removable media is disabled"

GDM_AMD_PACKAGES='gdm gdm3'
GDM_AMD_PROFILE_DIR='/etc/dconf/profile'
GDM_AMD_DB_BASE_DIR='/etc/dconf/db'

GDM_AMD_INSTALLED=1
GDM_AMD_PROFILE_NAME=''
GDM_AMD_KEYFILE_AUTOMOUNT=''
GDM_AMD_KEYFILE_AUTOMOUNT_OPEN=''

get_profile_from_keyfile() {
    local keyfile="$1"
    awk -F/ '{split($(NF-1),a,"."); print a[1]}' <<<"$keyfile"
}

audit() {
    for l_package in $GDM_AMD_PACKAGES; do
        is_pkg_installed "$l_package"
        if [ "$FNRET" = 0 ]; then
            ok "Package $l_package is installed"
            GDM_AMD_INSTALLED=0
            break
        fi
    done

    if [ "$GDM_AMD_INSTALLED" -ne 0 ]; then
        ok "GNOME Desktop Manager package is not installed on the system - Recommendation is not applicable"
        return
    fi

    GDM_AMD_KEYFILE_AUTOMOUNT=$(grep -Prils -- '^\h*automount\h*=' ${GDM_AMD_DB_BASE_DIR}/*.d 2>/dev/null | head -n1 || true)
    GDM_AMD_KEYFILE_AUTOMOUNT_OPEN=$(grep -Prils -- '^\h*automount-open\h*=' ${GDM_AMD_DB_BASE_DIR}/*.d 2>/dev/null | head -n1 || true)

    if [ -n "$GDM_AMD_KEYFILE_AUTOMOUNT" ]; then
        GDM_AMD_PROFILE_NAME=$(get_profile_from_keyfile "$GDM_AMD_KEYFILE_AUTOMOUNT")
    elif [ -n "$GDM_AMD_KEYFILE_AUTOMOUNT_OPEN" ]; then
        GDM_AMD_PROFILE_NAME=$(get_profile_from_keyfile "$GDM_AMD_KEYFILE_AUTOMOUNT_OPEN")
    fi

    if [ -z "$GDM_AMD_PROFILE_NAME" ]; then
        crit "automount and automount-open are not set correctly"
        return
    fi

    local l_gpdir="${GDM_AMD_DB_BASE_DIR}/${GDM_AMD_PROFILE_NAME}.d"
    local l_gpdb="${GDM_AMD_DB_BASE_DIR}/${GDM_AMD_PROFILE_NAME}"

    if grep -Pq -- "^\h*system-db:${GDM_AMD_PROFILE_NAME}\b" ${GDM_AMD_PROFILE_DIR}/* 2>/dev/null; then
        ok "dconf database profile file exists for ${GDM_AMD_PROFILE_NAME}"
    else
        crit "dconf database profile is not set for ${GDM_AMD_PROFILE_NAME}"
    fi

    if [ -f "$l_gpdb" ]; then
        ok "The dconf database ${GDM_AMD_PROFILE_NAME} exists"
    else
        crit "The dconf database ${GDM_AMD_PROFILE_NAME} does not exist"
    fi

    if [ -d "$l_gpdir" ]; then
        ok "The dconf directory ${l_gpdir} exists"
    else
        crit "The dconf directory ${l_gpdir} does not exist"
    fi

    if [ -n "$GDM_AMD_KEYFILE_AUTOMOUNT" ] && grep -Pqrs -- '^\h*automount\h*=\h*false\b' "$GDM_AMD_KEYFILE_AUTOMOUNT"; then
        ok "automount is set to false in ${GDM_AMD_KEYFILE_AUTOMOUNT}"
    else
        crit "automount is not set correctly"
    fi

    if [ -n "$GDM_AMD_KEYFILE_AUTOMOUNT_OPEN" ] && grep -Pqrs -- '^\h*automount-open\h*=\h*false\b' "$GDM_AMD_KEYFILE_AUTOMOUNT_OPEN"; then
        ok "automount-open is set to false in ${GDM_AMD_KEYFILE_AUTOMOUNT_OPEN}"
    else
        crit "automount-open is not set correctly"
    fi
}

apply() {
    if [ "$GDM_AMD_INSTALLED" -ne 0 ]; then
        ok "GNOME Desktop Manager is not installed, nothing to apply"
        return
    fi

    local l_gpname="${GDM_AMD_PROFILE_NAME:-local}"
    local l_gpdir="${GDM_AMD_DB_BASE_DIR}/${l_gpname}.d"
    local l_kfile="$l_gpdir/00-media-automount"

    if [ -n "$GDM_AMD_KEYFILE_AUTOMOUNT" ]; then
        l_kfile="$GDM_AMD_KEYFILE_AUTOMOUNT"
    elif [ -n "$GDM_AMD_KEYFILE_AUTOMOUNT_OPEN" ]; then
        l_kfile="$GDM_AMD_KEYFILE_AUTOMOUNT_OPEN"
    fi

    if ! grep -Pq -- "^\h*system-db:${l_gpname}\b" ${GDM_AMD_PROFILE_DIR}/* 2>/dev/null; then
        mkdir -p "$GDM_AMD_PROFILE_DIR"
        local l_gpfile="${GDM_AMD_PROFILE_DIR}/user"
        if [ -f "$l_gpfile" ] && ! grep -Pq -- "^\h*system-db:${l_gpname}\b" "$l_gpfile"; then
            l_gpfile="${GDM_AMD_PROFILE_DIR}/user2"
        fi
        info "Creating dconf database profile in $l_gpfile"
        {
            echo ""
            echo "user-db:user"
            echo "system-db:${l_gpname}"
        } >>"$l_gpfile"
    fi

    mkdir -p "$l_gpdir"

    if [ -f "$l_kfile" ]; then
        sed -i '/^\s*automount\s*=/d' "$l_kfile"
        sed -i '/^\s*automount-open\s*=/d' "$l_kfile"
    else
        echo "[org/gnome/desktop/media-handling]" >"$l_kfile"
    fi

    if ! grep -q '^\[org/gnome/desktop/media-handling\]' "$l_kfile"; then
        echo "[org/gnome/desktop/media-handling]" >>"$l_kfile"
    fi

    sed -i '/^\[org\/gnome\/desktop\/media-handling\]/a automount-open=false' "$l_kfile"
    sed -i '/^\[org\/gnome\/desktop\/media-handling\]/a automount=false' "$l_kfile"

    if command -v dconf >/dev/null 2>&1; then
        dconf update
    fi

    ok "automount and automount-open are set to false"
}

check_config() {
    :
}

if [ -r /etc/default/cis-hardening ]; then
    # shellcheck source=../../debian/default
    . /etc/default/cis-hardening
fi
if [ -z "${CIS_LIB_DIR}" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_LIB_DIR variable, aborting."
    exit 128
fi

if [ -r "${CIS_LIB_DIR}"/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "${CIS_LIB_DIR}"/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is ${CIS_LIB_DIR} in /etc/default/cis-hardening"
    exit 128
fi
