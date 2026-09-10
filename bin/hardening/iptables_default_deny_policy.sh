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
IPT_ACCEPT_EXCEPTIONS=""
IPT_INPUT_OK=1
IPT_OUTPUT_OK=1
IPT_FORWARD_OK=1
IPT_PACKAGE_INSTALLED=1

audit() {
    IPT_PACKAGE_INSTALLED=1

    is_pkg_installed "$IPT_PACKAGE"
    if [ "$FNRET" != 0 ]; then
        crit "$IPT_PACKAGE is not installed"
        return
    fi
    IPT_PACKAGE_INSTALLED=0

    local input_policy output_policy forward_policy
    input_policy=$($SUDO_CMD iptables -S INPUT 2>/dev/null | awk '/^-P/ {print $3}')
    output_policy=$($SUDO_CMD iptables -S OUTPUT 2>/dev/null | awk '/^-P/ {print $3}')
    forward_policy=$($SUDO_CMD iptables -S FORWARD 2>/dev/null | awk '/^-P/ {print $3}')

    if [ "$input_policy" = "DROP" ] || [ "$input_policy" = "REJECT" ]; then
        ok "INPUT policy is $input_policy"
        IPT_INPUT_OK=0
    elif grep -qw INPUT <<<"$IPT_ACCEPT_EXCEPTIONS"; then
        ok "INPUT policy is $input_policy and allowed by configuration"
        IPT_INPUT_OK=0
    else
        crit "INPUT policy is $input_policy, expected DROP or REJECT"
        IPT_INPUT_OK=1
    fi

    if [ "$output_policy" = "DROP" ] || [ "$output_policy" = "REJECT" ]; then
        ok "OUTPUT policy is $output_policy"
        IPT_OUTPUT_OK=0
    elif grep -qw OUTPUT <<<"$IPT_ACCEPT_EXCEPTIONS"; then
        ok "OUTPUT policy is $output_policy and allowed by configuration"
        IPT_OUTPUT_OK=0
    else
        crit "OUTPUT policy is $output_policy, expected DROP or REJECT"
        IPT_OUTPUT_OK=1
    fi

    if [ "$forward_policy" = "DROP" ] || [ "$forward_policy" = "REJECT" ]; then
        ok "FORWARD policy is $forward_policy"
        IPT_FORWARD_OK=0
    elif grep -qw FORWARD <<<"$IPT_ACCEPT_EXCEPTIONS"; then
        ok "FORWARD policy is $forward_policy and allowed by configuration"
        IPT_FORWARD_OK=0
    else
        crit "FORWARD policy is $forward_policy, expected DROP or REJECT"
        IPT_FORWARD_OK=1
    fi
}

apply() {
    if [ "$IPT_PACKAGE_INSTALLED" != 0 ]; then
        crit "$IPT_PACKAGE is not installed"
        return
    fi

    if [ "$IPT_INPUT_OK" -ne 0 ]; then
        if grep -qw INPUT <<<"$IPT_ACCEPT_EXCEPTIONS"; then
            info "Leaving INPUT policy unchanged because it is allowed by configuration"
        else
            info "Setting INPUT policy to DROP"
            iptables -P INPUT DROP
        fi
    fi
    if [ "$IPT_OUTPUT_OK" -ne 0 ]; then
        if grep -qw OUTPUT <<<"$IPT_ACCEPT_EXCEPTIONS"; then
            info "Leaving OUTPUT policy unchanged because it is allowed by configuration"
        else
            info "Setting OUTPUT policy to DROP"
            iptables -P OUTPUT DROP
        fi
    fi
    if [ "$IPT_FORWARD_OK" -ne 0 ]; then
        if grep -qw FORWARD <<<"$IPT_ACCEPT_EXCEPTIONS"; then
            info "Leaving FORWARD policy unchanged because it is allowed by configuration"
        else
            info "Setting FORWARD policy to DROP"
            iptables -P FORWARD DROP
        fi
    fi
}

create_config() {
    echo "status=audit"
    echo 'IPT_ACCEPT_EXCEPTIONS=""'
}

check_config() {
    local l_chain=""

    if [ -z "$IPT_ACCEPT_EXCEPTIONS" ]; then
        IPT_ACCEPT_EXCEPTIONS=""
    fi

    for l_chain in $IPT_ACCEPT_EXCEPTIONS; do
        if [ "$l_chain" != "INPUT" ] && [ "$l_chain" != "OUTPUT" ] && [ "$l_chain" != "FORWARD" ]; then
            crit "Invalid chain in IPT_ACCEPT_EXCEPTIONS: $l_chain"
        fi
    done
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
