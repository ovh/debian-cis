#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure message access server services are not in use (Automated)
#

set -e
set -u

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Ensure message access server services are not in use"

MAIL_PACKAGES='dovecot-imapd dovecot-pop3d'
MAIL_SERVICE='dovecot.service'
MAIL_SOCKET='dovecot.socket'

MAIL_ANY_INSTALLED=1

audit() {
    MAIL_ANY_INSTALLED=1
    for l_pkg in $MAIL_PACKAGES; do
        is_pkg_installed "$l_pkg"
        if [ "$FNRET" = 0 ]; then
            crit "$l_pkg is installed"
            MAIL_ANY_INSTALLED=0
        else
            ok "$l_pkg is not installed"
        fi
    done

    if [ "$MAIL_ANY_INSTALLED" -ne 0 ]; then
        return
    fi

    is_systemctl_running
    if [ "$FNRET" != 0 ]; then
        warn "systemd not running, skipping service state checks"
        return
    fi

    if systemctl is-enabled "$MAIL_SOCKET" "$MAIL_SERVICE" 2>/dev/null | grep -q 'enabled'; then
        crit "dovecot service/socket are enabled"
    else
        ok "dovecot service/socket are not enabled"
    fi

    if systemctl is-active "$MAIL_SOCKET" "$MAIL_SERVICE" 2>/dev/null | grep -q '^active'; then
        crit "dovecot service/socket are active"
    else
        ok "dovecot service/socket are not active"
    fi
}

apply() {
    local had_package=1
    for l_pkg in $MAIL_PACKAGES; do
        is_pkg_installed "$l_pkg"
        if [ "$FNRET" = 0 ]; then
            had_package=0
        fi
    done

    if [ "$had_package" -ne 0 ]; then
        ok "dovecot-imapd and dovecot-pop3d are not installed"
        return
    fi

    is_systemctl_running
    if [ "$FNRET" = 0 ]; then
        info "Stopping dovecot socket/service"
        systemctl stop "$MAIL_SOCKET" "$MAIL_SERVICE" >/dev/null 2>&1 || true
        info "Masking dovecot socket/service"
        systemctl mask "$MAIL_SOCKET" "$MAIL_SERVICE" >/dev/null 2>&1 || true
    fi

    info "Purging dovecot-imapd and dovecot-pop3d"
    apt-get purge -y dovecot-imapd dovecot-pop3d || true
    apt-get autoremove -y || true
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
