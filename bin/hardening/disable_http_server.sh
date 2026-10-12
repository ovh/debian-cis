#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure web server services are not in use (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure web server services are not in use."
# shellcheck disable=2034
HARDENING_EXCEPTION=http

PACKAGE_APACHE='apache2'
PACKAGE_NGINX='nginx'
SERVICE_APACHE='apache2.service'
SOCKET_APACHE='apache2.socket'
SERVICE_NGINX='nginx.service'

# Global state (0=true/success, 1=false/failure)
HTTP_SERVER_APACHE_INSTALLED=1
HTTP_SERVER_APACHE_IS_DEPENDENCY=1
HTTP_SERVER_APACHE_SERVICE_ENABLED=1
HTTP_SERVER_APACHE_SERVICE_ACTIVE=1
HTTP_SERVER_APACHE_SOCKET_ENABLED=1
HTTP_SERVER_APACHE_SOCKET_ACTIVE=1

HTTP_SERVER_NGINX_INSTALLED=1
HTTP_SERVER_NGINX_IS_DEPENDENCY=1
HTTP_SERVER_NGINX_SERVICE_ENABLED=1
HTTP_SERVER_NGINX_SERVICE_ACTIVE=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    HTTP_SERVER_APACHE_INSTALLED=1
    HTTP_SERVER_APACHE_IS_DEPENDENCY=1
    HTTP_SERVER_APACHE_SERVICE_ENABLED=1
    HTTP_SERVER_APACHE_SERVICE_ACTIVE=1
    HTTP_SERVER_APACHE_SOCKET_ENABLED=1
    HTTP_SERVER_APACHE_SOCKET_ACTIVE=1

    HTTP_SERVER_NGINX_INSTALLED=1
    HTTP_SERVER_NGINX_IS_DEPENDENCY=1
    HTTP_SERVER_NGINX_SERVICE_ENABLED=1
    HTTP_SERVER_NGINX_SERVICE_ACTIVE=1

    is_pkg_installed "$PACKAGE_APACHE"
    if [ "$FNRET" -eq 0 ]; then
        HTTP_SERVER_APACHE_INSTALLED=0
    fi

    is_pkg_installed "$PACKAGE_NGINX"
    if [ "$FNRET" -eq 0 ]; then
        HTTP_SERVER_NGINX_INSTALLED=0
    fi

    if [ "$HTTP_SERVER_APACHE_INSTALLED" -ne 0 ] && [ "$HTTP_SERVER_NGINX_INSTALLED" -ne 0 ]; then
        ok "$PACKAGE_APACHE is not installed"
        ok "$PACKAGE_NGINX is not installed"
        return
    fi

    if [ "$HTTP_SERVER_APACHE_INSTALLED" -eq 0 ]; then
        is_pkg_a_dependency "$PACKAGE_APACHE"
        if [ "$FNRET" -eq 0 ]; then
            HTTP_SERVER_APACHE_IS_DEPENDENCY=0
        fi

        if [ "$HTTP_SERVER_APACHE_IS_DEPENDENCY" -ne 0 ]; then
            crit "$PACKAGE_APACHE is installed and not a dependency"
        else
            is_service_enabled "$SERVICE_APACHE"
            if [ "$FNRET" -eq 0 ]; then
                HTTP_SERVER_APACHE_SERVICE_ENABLED=0
                crit "$SERVICE_APACHE is enabled"
            fi

            is_service_active "$SERVICE_APACHE"
            if [ "$FNRET" -eq 0 ]; then
                HTTP_SERVER_APACHE_SERVICE_ACTIVE=0
                crit "$SERVICE_APACHE is active"
            fi

            is_socket_enabled "$SOCKET_APACHE"
            if [ "$FNRET" -eq 0 ]; then
                HTTP_SERVER_APACHE_SOCKET_ENABLED=0
                crit "$SOCKET_APACHE is enabled"
            fi

            is_socket_active "$SOCKET_APACHE"
            if [ "$FNRET" -eq 0 ]; then
                HTTP_SERVER_APACHE_SOCKET_ACTIVE=0
                crit "$SOCKET_APACHE is active"
            fi

            if [ "$HTTP_SERVER_APACHE_SERVICE_ENABLED" -ne 0 ] &&
                [ "$HTTP_SERVER_APACHE_SERVICE_ACTIVE" -ne 0 ] &&
                [ "$HTTP_SERVER_APACHE_SOCKET_ENABLED" -ne 0 ] &&
                [ "$HTTP_SERVER_APACHE_SOCKET_ACTIVE" -ne 0 ]; then
                ok "$PACKAGE_APACHE is used as a dependency and $SERVICE_APACHE/$SOCKET_APACHE are not enabled/active"
            fi
        fi
    fi

    if [ "$HTTP_SERVER_NGINX_INSTALLED" -eq 0 ]; then
        is_pkg_a_dependency "$PACKAGE_NGINX"
        if [ "$FNRET" -eq 0 ]; then
            HTTP_SERVER_NGINX_IS_DEPENDENCY=0
        fi

        if [ "$HTTP_SERVER_NGINX_IS_DEPENDENCY" -ne 0 ]; then
            crit "$PACKAGE_NGINX is installed and not a dependency"
        else
            is_service_enabled "$SERVICE_NGINX"
            if [ "$FNRET" -eq 0 ]; then
                HTTP_SERVER_NGINX_SERVICE_ENABLED=0
                crit "$SERVICE_NGINX is enabled"
            fi

            is_service_active "$SERVICE_NGINX"
            if [ "$FNRET" -eq 0 ]; then
                HTTP_SERVER_NGINX_SERVICE_ACTIVE=0
                crit "$SERVICE_NGINX is active"
            fi

            if [ "$HTTP_SERVER_NGINX_SERVICE_ENABLED" -ne 0 ] && [ "$HTTP_SERVER_NGINX_SERVICE_ACTIVE" -ne 0 ]; then
                ok "$PACKAGE_NGINX is used as a dependency and $SERVICE_NGINX is not enabled/active"
            fi
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    local removed_any
    removed_any=1

    if [ "$HTTP_SERVER_APACHE_INSTALLED" -eq 0 ] && [ "$HTTP_SERVER_APACHE_IS_DEPENDENCY" -ne 0 ]; then
        info "$PACKAGE_APACHE is installed and not a dependency, removing it"
        apt-get purge "$PACKAGE_APACHE" -y
        removed_any=0
    fi

    if [ "$HTTP_SERVER_NGINX_INSTALLED" -eq 0 ] && [ "$HTTP_SERVER_NGINX_IS_DEPENDENCY" -ne 0 ]; then
        info "$PACKAGE_NGINX is installed and not a dependency, removing it"
        apt-get purge "$PACKAGE_NGINX" -y
        removed_any=0
    fi

    if [ "$removed_any" -eq 0 ]; then
        apt-get autoremove -y
    fi

    if [ "$HTTP_SERVER_APACHE_INSTALLED" -eq 0 ] && [ "$HTTP_SERVER_APACHE_IS_DEPENDENCY" -eq 0 ]; then
        is_systemctl_running
        if [ "$FNRET" -ne 0 ]; then
            warn "systemd not running, cannot stop/mask $SERVICE_APACHE and $SOCKET_APACHE"
        elif [ "$HTTP_SERVER_APACHE_SERVICE_ENABLED" -eq 0 ] ||
            [ "$HTTP_SERVER_APACHE_SERVICE_ACTIVE" -eq 0 ] ||
            [ "$HTTP_SERVER_APACHE_SOCKET_ENABLED" -eq 0 ] ||
            [ "$HTTP_SERVER_APACHE_SOCKET_ACTIVE" -eq 0 ]; then
            info "Stopping and masking $SERVICE_APACHE and $SOCKET_APACHE"
            systemctl stop "$SOCKET_APACHE" "$SERVICE_APACHE" || true
            systemctl mask "$SOCKET_APACHE" "$SERVICE_APACHE"
        else
            ok "$SERVICE_APACHE and $SOCKET_APACHE already not enabled/active"
        fi
    fi

    if [ "$HTTP_SERVER_NGINX_INSTALLED" -eq 0 ] && [ "$HTTP_SERVER_NGINX_IS_DEPENDENCY" -eq 0 ]; then
        is_systemctl_running
        if [ "$FNRET" -ne 0 ]; then
            warn "systemd not running, cannot stop/mask $SERVICE_NGINX"
        elif [ "$HTTP_SERVER_NGINX_SERVICE_ENABLED" -eq 0 ] || [ "$HTTP_SERVER_NGINX_SERVICE_ACTIVE" -eq 0 ]; then
            info "Stopping and masking $SERVICE_NGINX"
            systemctl stop "$SERVICE_NGINX" || true
            systemctl mask "$SERVICE_NGINX"
        else
            ok "$SERVICE_NGINX already not enabled/active"
        fi
    fi

    if [ "$HTTP_SERVER_APACHE_INSTALLED" -ne 0 ] && [ "$HTTP_SERVER_NGINX_INSTALLED" -ne 0 ]; then
        ok "$PACKAGE_APACHE is not installed"
        ok "$PACKAGE_NGINX is not installed"
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
