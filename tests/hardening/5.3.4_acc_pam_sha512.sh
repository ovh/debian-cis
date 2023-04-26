# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    register_test contain REGEX "[ OK ] .*(sha512|yescrypt) is present in /etc/pam.d/common-password"
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all
}
