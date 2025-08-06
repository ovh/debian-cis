# shellcheck shell=bash
# run-shellcheck
test_audit() {
    local APT_KEY_FILE="/etc/apt/trusted.gpg"
    local APT_KEY_PATH="/etc/apt/trusted.gpg.d"
    local unsecure_source="/etc/apt/sources.list.d/unsecure.list"
    local unsecure_conf_file="/etc/apt/apt.conf.d/unsecure"

    # make sure we don't have any key
    [ -f "$APT_KEY_FILE" ] && mv "$APT_KEY_FILE" /tmp
    [ -d "$APT_KEY_PATH" ] && mv "$APT_KEY_PATH" /tmp

    describe Running non compliant missing keys
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # fix the situation
    [ -d /tmp/trusted.gpg.d ] && mv /tmp/trusted.gpg.d /etc/apt/
    [ -f /tmp/trusted.gpg ] && mv /tmp/trusted.gpg /etc/apt/

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    echo 'deb [allow-insecure=yes] http://deb.debian.org/debian bookworm main' >"$unsecure_source"
    describe Running non compliant unsecure option in sources list
    register_test retvalshouldbe 1
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    rm -f "$unsecure_source"

    echo 'Acquire::AllowInsecureRepositories=true' >"$unsecure_conf_file"
    describe Running non compliant unsecure option in apt conf
    register_test retvalshouldbe 1
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    rm -f "$unsecure_conf_file"

}
