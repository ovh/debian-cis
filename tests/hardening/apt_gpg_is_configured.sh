# shellcheck shell=bash
# run-shellcheck
test_audit() {
    local APT_KEY_FILE="/etc/apt/trusted.gpg"
    local APT_KEY_PATH="/etc/apt/trusted.gpg.d"
    local unsecure_source="/etc/apt/sources.list.d/unsecure.list"
    local unsecure_deb822="/etc/apt/sources.list.d/unsecure.sources"
    local unsecure_conf_file="/etc/apt/apt.conf.d/99-cis-test-unsecure"

    # make sure we don't have any key
    [ -f "$APT_KEY_FILE" ] && mv "$APT_KEY_FILE" /tmp
    [ -d "$APT_KEY_PATH" ] && mv "$APT_KEY_PATH" /tmp

    describe Running non compliant missing keys
    register_test retvalshouldbe 1
    # shellcheck disable=2154
    run noncompliant "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    # restore the key material used by the image
    [ -d /tmp/trusted.gpg.d ] && mv /tmp/trusted.gpg.d /etc/apt/
    [ -f /tmp/trusted.gpg ] && mv /tmp/trusted.gpg /etc/apt/

    describe Checking resolved state
    register_test retvalshouldbe 0
    run resolved "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    echo 'deb [allow-insecure=yes] http://deb.debian.org/debian bookworm main' >"$unsecure_source"
    describe Running non compliant insecure option in sources.list
    register_test retvalshouldbe 1
    run list_insecure "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
    rm -f "$unsecure_source"

    cat >"$unsecure_deb822" <<'EOF'
Types: deb
URIs: http://deb.debian.org/debian
Suites: bookworm
Components: main
Trusted: yes
EOF
    describe Running non compliant Trusted option in deb822 source
    register_test retvalshouldbe 1
    run deb822_trusted "${CIS_CHECKS_DIR}/${script}.sh" --audit-all

    echo 'Enabled: no' >>"$unsecure_deb822"
    describe Ignoring disabled deb822 source
    register_test retvalshouldbe 0
    run deb822_disabled "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
    rm -f "$unsecure_deb822"

    echo 'Acquire::AllowInsecureRepositories "true";' >"$unsecure_conf_file"
    describe Running non compliant effective APT option
    register_test retvalshouldbe 1
    run global_insecure "${CIS_CHECKS_DIR}/${script}.sh" --audit-all
    rm -f "$unsecure_conf_file"
}
