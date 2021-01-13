# shellcheck shell=bash
# run-shellcheck
test_audit() {
    describe Running on blank host
    register_test retvalshouldbe 0
    dismiss_count_for_test
    # shellcheck disable=2154
    run blank /opt/debian-cis/bin/hardening/"${script}".sh --audit-all

    describe Correcting situation
    sed -i 's/audit/enabled/' /opt/debian-cis/etc/conf.d/"${script}".cfg
    /opt/debian-cis/bin/hardening/"${script}".sh || true

    describe Checking resolved state
    register_test retvalshouldbe 0
    register_test contain "[ OK ] ^auth[[:space:]]*required[[:space:]]*pam_tally[2]?\.so is present in /etc/pam.d/common-auth"
    register_test contain "[ OK ] pam_tally[2]?\.so is present in /etc/pam.d/common-account"
    run resolved /opt/debian-cis/bin/hardening/"${script}".sh --audit-all
}
