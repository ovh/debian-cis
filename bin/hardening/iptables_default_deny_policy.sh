#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure iptables default deny firewall policy (Automated)
#

set -e
set -u

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Ensure iptables default deny firewall policy"

IPT_PACKAGE='iptables'
IPT_INPUT_OK=1
IPT_OUTPUT_OK=1
IPT_FORWARD_OK=1

audit() {
    is_pkg_installed "$IPT_PACKAGE"
    if [ "$FNRET" != 0 ]; then
        crit "$IPT_PACKAGE is not installed"
        return
    fi

    local input_policy output_policy forward_policy
    input_policy=$($SUDO_CMD iptables -S INPUT 2>/dev/null | awk '/^-P/ {print $3}')
    output_policy=$($SUDO_CMD iptables -S OUTPUT 2>/dev/null | awk '/^-P/ {print $3}')
    forward_policy=$($SUDO_CMD iptables -S FORWARD 2>/dev/null | awk '/^-P/ {print $3}')

    if [ "$input_policy" = "DROP" ] || [ "$input_policy" = "REJECT" ]; then
        ok "INPUT policy is $input_policy"
        IPT_INPUT_OK=0
    else
        crit "INPUT policy is $input_policy, expected DROP or REJECT"
        IPT_INPUT_OK=1
    fi

    if [ "$output_policy" = "DROP" ] || [ "$output_policy" = "REJECT" ]; then
        ok "OUTPUT policy is $output_policy"
        IPT_OUTPUT_OK=0
    else
        crit "OUTPUT policy is $output_policy, expected DROP or REJECT"
        IPT_OUTPUT_OK=1
    fi

    if [ "$forward_policy" = "DROP" ] || [ "$forward_policy" = "REJECT" ]; then
        ok "FORWARD policy is $forward_policy"
        IPT_FORWARD_OK=0
    else
        crit "FORWARD policy is $forward_policy, expected DROP or REJECT"
        IPT_FORWARD_OK=1
    fi
}

apply() {
    is_pkg_installed "$IPT_PACKAGE"
    if [ "$FNRET" != 0 ]; then
        crit "$IPT_PACKAGE is not installed"
        return
    fi

    if [ "$IPT_INPUT_OK" -ne 0 ]; then
        info "Setting INPUT policy to DROP"
        iptables -P INPUT DROP
    fi
    if [ "$IPT_OUTPUT_OK" -ne 0 ]; then
        info "Setting OUTPUT policy to DROP"
        iptables -P OUTPUT DROP
    fi
    if [ "$IPT_FORWARD_OK" -ne 0 ]; then
        info "Setting FORWARD policy to DROP"
        iptables -P FORWARD DROP
    fi
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
